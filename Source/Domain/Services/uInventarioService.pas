unit uInventarioService;

interface

uses
  System.SysUtils, JS, Web, uHttp;

type
  TSeccion = class
  public
    Id: Integer;
    Nombre: string;
  end;

  TResultadoSecciones = class
  public
    Ok: Boolean;
    Error: string;
    Items: array of TSeccion;
  end;

  TProducto = class
  public
    Id: Integer;
    SeccionId: Integer;
    Nombre: string;
    TipoVenta: string;          // tal como está en la BD: 'peso', 'paquete_peso' o 'unidad'
    LibrasPorPaquete: Double;
    Precio: Double;
    Stock: Double;
    Nota: string;
    Visible: Boolean;
  end;

  TResultadoProductos = class
  public
    Ok: Boolean;
    Error: string;
    Items: array of TProducto;
  end;

  TResultado = class
  public
    Ok: Boolean;
    Error: string;
  end;

  TProductoNuevo = record
    SeccionId: Integer;
    Nombre: string;
    Nota: string;               // opcional (ej. '1lb-950')
    TipoVenta: string;          // 'lb', 'paq' o 'u' (lo que elige la pantalla)
    LibrasPorPaquete: Double;   // solo cuenta si TipoVenta = 'paq'
    Costo: Double;              // CUP por unidad de venta
    CostoExtra: Double;
    Insumo: Double;
    Precio: Double;             // CUP
    Stock: Double;
    Visible: Boolean;
  end;

  TInventarioService = class
  public
    [async]
    class function CargarSecciones: TResultadoSecciones;
    [async]
    class function CargarProductos: TResultadoProductos;
    [async]
    class function CrearProducto(P: TProductoNuevo): TResultado;
  end;

implementation

uses
  uSession;

const
  // Valores que acepta productos.tipo_venta en la BD
  TV_LIBRA = 'peso';
  TV_PAQUETE = 'paquete_peso';
  TV_UNIDAD = 'unidad';

function Token: string;
begin
  Result := TSession.Token;
end;

function Redondear(V: Double; Decimales: Integer): Double;
var
  F: Double;
begin
  if Decimales = 3 then F := 1000 else F := 100;
  Result := Round(V * F) / F;
end;

// Los campos vacíos de la BD llegan como null: se leen como '' o 0
function TextoJS(V: JSValue): string;
begin
  if isNull(V) or isUndefined(V) then
    Result := ''
  else
    Result := string(V);
end;

function NumeroJS(V: JSValue): Double;
begin
  if isNull(V) or isUndefined(V) then
    Result := 0
  else
    Result := Double(V);
end;

function MensajeError(R: TApiResponse): string;
begin
  case R.Status of
    0:   Result := 'Sin conexión. Revisa tu internet e intenta de nuevo.';
    401: Result := 'Tu sesión venció. Vuelve a iniciar sesión.';
    403: Result := 'No tienes permiso para hacer esto.';
  else
    Result := 'No se pudo completar la operación (' + IntToStr(R.Status) + ').';
  end;
  console.log('Error BD ' + IntToStr(R.Status) + ': ' + R.Body);   // detalle técnico
end;

class function TInventarioService.CargarSecciones: TResultadoSecciones;
var
  R: TApiResponse;
  Arr: TJSArray;
  Obj: TJSObject;
  S: TSeccion;
  i: Integer;
begin
  Result := TResultadoSecciones.Create;
  R := await(TApiResponse, THttp.Send('GET',
    '/rest/v1/secciones?select=id,nombre&activa=eq.true&order=orden.asc,nombre.asc',
    '', Token));
  if not R.Ok then
  begin
    Result.Error := MensajeError(R);
    Exit;
  end;

  Arr := TJSArray(TJSJSON.parse(R.Body));
  SetLength(Result.Items, Arr.length);
  for i := 0 to Arr.length - 1 do
  begin
    Obj := TJSObject(Arr[i]);
    S := TSeccion.Create;
    S.Id := Integer(Obj['id']);
    S.Nombre := string(Obj['nombre']);
    Result.Items[i] := S;
  end;
  Result.Ok := True;
end;

class function TInventarioService.CargarProductos: TResultadoProductos;
var
  R: TApiResponse;
  Arr: TJSArray;
  Obj: TJSObject;
  P: TProducto;
  i: Integer;
begin
  Result := TResultadoProductos.Create;
  R := await(TApiResponse, THttp.Send('GET',
    '/rest/v1/productos?select=id,seccion_id,nombre,tipo_venta,libras_por_paquete,'
    + 'precio_cup,stock,nota,visible&activo=eq.true&order=orden.asc,nombre.asc',
    '', Token));
  if not R.Ok then
  begin
    Result.Error := MensajeError(R);
    Exit;
  end;

  Arr := TJSArray(TJSJSON.parse(R.Body));
  SetLength(Result.Items, Arr.length);
  for i := 0 to Arr.length - 1 do
  begin
    Obj := TJSObject(Arr[i]);
    P := TProducto.Create;
    P.Id := Integer(Obj['id']);
    P.SeccionId := Integer(Obj['seccion_id']);
    P.Nombre := TextoJS(Obj['nombre']);
    P.TipoVenta := TextoJS(Obj['tipo_venta']);
    P.LibrasPorPaquete := NumeroJS(Obj['libras_por_paquete']);
    P.Precio := NumeroJS(Obj['precio_cup']);
    P.Stock := NumeroJS(Obj['stock']);
    P.Nota := TextoJS(Obj['nota']);
    P.Visible := Boolean(Obj['visible']);
    Result.Items[i] := P;
  end;
  Result.Ok := True;
end;

class function TInventarioService.CrearProducto(P: TProductoNuevo): TResultado;
var
  O: TJSObject;
  R: TApiResponse;
begin
  Result := TResultado.Create;

  O := TJSObject.new;
  O['seccion_id'] := P.SeccionId;
  O['nombre'] := Trim(P.Nombre);
  O['costo_cup'] := Redondear(P.Costo, 2);
  O['costo_extra_cup'] := Redondear(P.CostoExtra, 2);
  O['insumo_cup'] := Redondear(P.Insumo, 2);
  O['precio_cup'] := Redondear(P.Precio, 2);
  O['visible'] := P.Visible;
  if Trim(P.Nota) <> '' then
    O['nota'] := Trim(P.Nota);

  if P.TipoVenta = 'paq' then
  begin
    O['tipo_venta'] := TV_PAQUETE;
    O['libras_por_paquete'] := Redondear(P.LibrasPorPaquete, 3);
    O['stock'] := Round(P.Stock);                 // paquetes enteros
  end
  else if P.TipoVenta = 'u' then
  begin
    O['tipo_venta'] := TV_UNIDAD;
    O['stock'] := Round(P.Stock);                 // unidades enteras
  end
  else
  begin
    O['tipo_venta'] := TV_LIBRA;
    O['stock'] := Redondear(P.Stock, 3);          // libras con hasta 3 decimales
  end;

  R := await(TApiResponse, THttp.Send('POST', '/rest/v1/productos',
    TJSJSON.stringify(O), Token));
  Result.Ok := R.Ok;
  if not R.Ok then
    Result.Error := MensajeError(R);
end;

end.
