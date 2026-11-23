unit uInventarioService;

interface

uses
  System.SysUtils, JS, Web, uHttp;

type
  TSeccion = class
  public
    Id: Integer;
    Nombre: string;
    Orden: Integer;
    Activa: Boolean;
    Productos: Integer;
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
    Costo: Double;
    CostoExtra: Double;
    Insumo: Double;
    FotoUrl: string;            // '' = sin foto
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

  TResultadoFoto = class
  public
    Ok: Boolean;
    Error: string;
    Url: string;                // dirección pública de la foto subida
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
    FotoUrl: string;            // foto nueva ya subida ('' = no cambia)
    QuitarFoto: Boolean;        // al editar: dejar el producto sin foto
  end;

  TInventarioService = class
  public
    [async]
    class function CargarSecciones: TResultadoSecciones;
    [async]
    class function CargarSeccionesTodas: TResultadoSecciones;
    [async]
    class function CargarProductos: TResultadoProductos;
    [async]
    class function CrearProducto(P: TProductoNuevo): TResultado;
    [async]
    class function ActualizarProducto(Id: Integer; P: TProductoNuevo): TResultado;
    [async]
    class function ActualizarStock(Id: Integer; Stock: Double): TResultado;
    [async]
    class function CrearSeccion(const Nombre: string; Orden: Integer; Activa: Boolean): TResultado;
    [async]
    class function ActualizarSeccion(Id: Integer; const Campo: string; Valor: JSValue): TResultado;
    [async]
    class function EliminarSeccion(Id: Integer): TResultado;
    [async]
    class function ContarProductos(SeccionId: Integer): Integer;
    [async]
    class function SubirFoto(Archivo: TJSObject): TResultadoFoto;
    [async]
    class function BorrarFoto(const Url: string): TResultado;
  end;

implementation

uses
  uSession, uConfig;

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

{ ---------- fotos (Supabase Storage, bucket "productos") ---------- }

function NuevaRuta: string;
begin
  asm
    Result = 'p_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8) + '.jpg';
  end;
end;

// Nunca falla: devuelve {status, body}. Sin red o tiempo agotado => status 0.
function SubirFetch(Archivo: TJSObject; const Base, Ruta, ApiKey, Token: string): TJSPromise;
begin
  asm
    var ctrl = new AbortController();
    var timer = setTimeout(function () { ctrl.abort(); }, 120000);
    Result = fetch(Base + '/storage/v1/object/productos/' + Ruta, {
      method: 'POST',
      headers: { 'apikey': ApiKey, 'Authorization': 'Bearer ' + Token, 'Content-Type': 'image/jpeg' },
      body: Archivo,
      signal: ctrl.signal
    }).then(function (r) {
      return r.text().then(function (t) { clearTimeout(timer); return { status: r.status, body: t }; });
    }).catch(function () { clearTimeout(timer); return { status: 0, body: '' }; });
  end;
end;

function BorrarFetch(const Base, Ruta, ApiKey, Token: string): TJSPromise;
begin
  asm
    Result = fetch(Base + '/storage/v1/object/productos/' + Ruta, {
      method: 'DELETE',
      headers: { 'apikey': ApiKey, 'Authorization': 'Bearer ' + Token }
    }).then(function (r) { return { status: r.status, body: '' }; })
      .catch(function () { return { status: 0, body: '' }; });
  end;
end;

class function TInventarioService.SubirFoto(Archivo: TJSObject): TResultadoFoto;
var
  Ruta: string;
  Res: TJSObject;
  Estado: Integer;
begin
  Result := TResultadoFoto.Create;
  Ruta := NuevaRuta;
  Res := await(TJSObject, SubirFetch(Archivo, SB_URL, Ruta, SB_KEY, Token));
  Estado := Integer(Res['status']);
  if (Estado >= 200) and (Estado < 300) then
  begin
    Result.Url := SB_URL + '/storage/v1/object/public/productos/' + Ruta;
    Result.Ok := True;
    Exit;
  end;
  console.log('Error subiendo foto ' + IntToStr(Estado) + ': ' + string(Res['body']));
  if Estado = 0 then
    Result.Error := 'Sin conexión. No se pudo subir la foto.'
  else if (Estado = 400) or (Estado = 401) or (Estado = 403) then
    Result.Error := 'Sin permiso para subir fotos (revisa las políticas de Storage).'
  else
    Result.Error := 'No se pudo subir la foto (' + IntToStr(Estado) + ').';
end;

// Borra del almacenamiento una foto que subimos nosotros; si falla, no pasa nada
class function TInventarioService.BorrarFoto(const Url: string): TResultado;
var
  Marca, Ruta: string;
  P: Integer;
  Res: TJSObject;
begin
  Result := TResultado.Create;
  Marca := '/storage/v1/object/public/productos/';
  P := Pos(Marca, Url);
  if P = 0 then Exit;
  Ruta := Copy(Url, P + Length(Marca), 200);
  Res := await(TJSObject, BorrarFetch(SB_URL, Ruta, SB_KEY, Token));
  Result.Ok := (Integer(Res['status']) >= 200) and (Integer(Res['status']) < 300);
end;

{ ---------- secciones ---------- }

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

class function TInventarioService.CargarSeccionesTodas: TResultadoSecciones;
var
  R: TApiResponse;
  Arr: TJSArray;
  Obj: TJSObject;
  S: TSeccion;
  i: Integer;
begin
  Result := TResultadoSecciones.Create;
  R := await(TApiResponse, THttp.Send('GET',
    '/rest/v1/secciones?select=id,nombre,orden,activa&order=orden.asc,id.asc',
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
    S.Nombre := TextoJS(Obj['nombre']);
    S.Orden := Round(NumeroJS(Obj['orden']));
    S.Activa := Boolean(Obj['activa']);
    Result.Items[i] := S;
  end;
  Result.Ok := True;
end;

class function TInventarioService.CrearSeccion(const Nombre: string; Orden: Integer;
  Activa: Boolean): TResultado;
var
  O: TJSObject;
  R: TApiResponse;
begin
  Result := TResultado.Create;
  O := TJSObject.new;
  O['nombre'] := Trim(Nombre);
  O['orden'] := Orden;
  O['activa'] := Activa;
  O['visible'] := True;
  R := await(TApiResponse, THttp.Send('POST', '/rest/v1/secciones',
    TJSJSON.stringify(O), Token));
  Result.Ok := R.Ok;
  if not R.Ok then
    Result.Error := MensajeError(R);
end;

class function TInventarioService.ActualizarSeccion(Id: Integer; const Campo: string;
  Valor: JSValue): TResultado;
var
  O: TJSObject;
  R: TApiResponse;
begin
  Result := TResultado.Create;
  O := TJSObject.new;
  O[Campo] := Valor;
  R := await(TApiResponse, THttp.Send('PATCH', '/rest/v1/secciones?id=eq.' + IntToStr(Id),
    TJSJSON.stringify(O), Token));
  Result.Ok := R.Ok;
  if not R.Ok then
    Result.Error := MensajeError(R)
  else if Trim(R.Body) = '[]' then
  begin
    Result.Ok := False;
    Result.Error := 'No tienes permiso para cambiar secciones.';
  end;
end;

class function TInventarioService.EliminarSeccion(Id: Integer): TResultado;
var
  R: TApiResponse;
begin
  Result := TResultado.Create;
  R := await(TApiResponse, THttp.Send('DELETE', '/rest/v1/secciones?id=eq.' + IntToStr(Id),
    '', Token));
  Result.Ok := R.Ok;
  if not R.Ok then
  begin
    if R.Status = 409 then
    begin
      console.log('Error BD 409: ' + R.Body);
      Result.Error := 'Tiene productos asociados. Desactívala en vez de borrarla.';
    end
    else
      Result.Error := MensajeError(R);
  end
  else if Trim(R.Body) = '[]' then
  begin
    Result.Ok := False;
    Result.Error := 'No tienes permiso para eliminar secciones.';
  end;
end;

// -1 si no se pudo consultar. Cuenta todos los productos, también los ocultos.
class function TInventarioService.ContarProductos(SeccionId: Integer): Integer;
var
  R: TApiResponse;
begin
  R := await(TApiResponse, THttp.Send('GET',
    '/rest/v1/productos?select=id&seccion_id=eq.' + IntToStr(SeccionId) + '&limit=1',
    '', Token));
  if not R.Ok then
  begin
    console.log('Error BD ' + IntToStr(R.Status) + ': ' + R.Body);
    Result := -1;
    Exit;
  end;
  Result := TJSArray(TJSJSON.parse(R.Body)).length;
end;

{ ---------- productos ---------- }

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
    + 'precio_cup,costo_cup,costo_extra_cup,insumo_cup,stock,nota,visible,foto_url'
    + '&activo=eq.true&order=orden.asc,nombre.asc',
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
    P.Costo := NumeroJS(Obj['costo_cup']);
    P.CostoExtra := NumeroJS(Obj['costo_extra_cup']);
    P.Insumo := NumeroJS(Obj['insumo_cup']);
    P.Stock := NumeroJS(Obj['stock']);
    P.Nota := TextoJS(Obj['nota']);
    P.Visible := Boolean(Obj['visible']);
    P.FotoUrl := TextoJS(Obj['foto_url']);
    Result.Items[i] := P;
  end;
  Result.Ok := True;
end;

function ArmarJson(P: TProductoNuevo; Editando: Boolean): string;
var
  O: TJSObject;
begin
  O := TJSObject.new;
  O['seccion_id'] := P.SeccionId;
  O['nombre'] := Trim(P.Nombre);
  O['costo_cup'] := Redondear(P.Costo, 2);
  O['costo_extra_cup'] := Redondear(P.CostoExtra, 2);
  O['insumo_cup'] := Redondear(P.Insumo, 2);
  O['precio_cup'] := Redondear(P.Precio, 2);
  O['visible'] := P.Visible;
  if P.FotoUrl <> '' then
    O['foto_url'] := P.FotoUrl
  else if Editando and P.QuitarFoto then
    O['foto_url'] := null;                      // dejar el producto sin foto
  if Trim(P.Nota) <> '' then
    O['nota'] := Trim(P.Nota)
  else if Editando then
    O['nota'] := null;                          // permite borrar la nota

  if P.TipoVenta = 'paq' then
  begin
    O['tipo_venta'] := TV_PAQUETE;
    O['libras_por_paquete'] := Redondear(P.LibrasPorPaquete, 3);
    O['stock'] := Round(P.Stock);
  end
  else if P.TipoVenta = 'u' then
  begin
    O['tipo_venta'] := TV_UNIDAD;
    O['stock'] := Round(P.Stock);
    if Editando then O['libras_por_paquete'] := null;
  end
  else
  begin
    O['tipo_venta'] := TV_LIBRA;
    O['stock'] := Redondear(P.Stock, 3);
    if Editando then O['libras_por_paquete'] := null;
  end;
  Result := TJSJSON.stringify(O);
end;

class function TInventarioService.CrearProducto(P: TProductoNuevo): TResultado;
var
  R: TApiResponse;
begin
  Result := TResultado.Create;
  R := await(TApiResponse, THttp.Send('POST', '/rest/v1/productos',
    ArmarJson(P, False), Token));
  Result.Ok := R.Ok;
  if not R.Ok then
    Result.Error := MensajeError(R);
end;

class function TInventarioService.ActualizarProducto(Id: Integer; P: TProductoNuevo): TResultado;
var
  R: TApiResponse;
begin
  Result := TResultado.Create;
  R := await(TApiResponse, THttp.Send('PATCH', '/rest/v1/productos?id=eq.' + IntToStr(Id),
    ArmarJson(P, True), Token));
  Result.Ok := R.Ok;
  if not R.Ok then
    Result.Error := MensajeError(R);
end;

class function TInventarioService.ActualizarStock(Id: Integer; Stock: Double): TResultado;
var
  O: TJSObject;
  R: TApiResponse;
begin
  Result := TResultado.Create;
  O := TJSObject.new;
  O['stock'] := Stock;
  R := await(TApiResponse, THttp.Send('PATCH', '/rest/v1/productos?id=eq.' + IntToStr(Id),
    TJSJSON.stringify(O), Token));
  Result.Ok := R.Ok;
  if not R.Ok then
    Result.Error := MensajeError(R);
end;

end.
