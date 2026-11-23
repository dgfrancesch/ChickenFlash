unit fAddProduct;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, WEBLib.StdCtrls, Vcl.Controls, WEBLib.ExtCtrls,
  Vcl.StdCtrls, WEBLib.WebCtrls;

type
  TForm4 = class(TWebForm)
    divAddSeccion: TWebHTMLDiv;
    btnAddCambiarFoto: TWebButton;
    edtAddCosto: TWebSpinEdit;
    lblUnidad: TWebHTMLSpan;
    btnAddQuitarFoto: TWebButton;
    btnAddGuardar: TWebButton;
    divHints: TWebHTMLDiv;
    lblAddGuardar: TWebHTMLSpan;
    btnAddVisible: TWebButton;
    btnAddUniU: TWebButton;
    edtAddNombre: TWebEdit;
    edtAddExtra: TWebSpinEdit;
    divAddToast: TWebHTMLDiv;
    imgAddFoto: TWebImageControl;
    lblAddError: TWebHTMLDiv;
    divPaquete: TWebHTMLDiv;
    btnAddCancelar: TWebButton;
    edtLibras: TWebSpinEdit;
    btnAddUniLb: TWebButton;
    edtAddStock: TWebSpinEdit;
    edtAddPrecio: TWebSpinEdit;
    lblAddToast: TWebHTMLSpan;
    edtAddInsumo: TWebSpinEdit;
    btnAddUniPaq: TWebButton;
    divAgregar: TWebHTMLDiv;
    divAddFotoPrev: TWebHTMLDiv;
    lblAddRed: TWebHTMLSpan;
    edtAddNota: TWebEdit;
    btnAddFoto: TWebButton;
    btnAddVolver: TWebButton;
    procedure WebFormCreate(Sender: TObject);
    procedure btnAddCancelarClick(Sender: TObject);
    procedure btnAddVolverClick(Sender: TObject);
    procedure btnUniLbClick(Sender: TObject);
    procedure btnUniPaqClic(Sender: TObject);
    procedure btnUniPaqClick(Sender: TObject);
    procedure btnAddUniLbClick(Sender: TObject);
    procedure btnAddUniUClick(Sender: TObject);
    procedure btnVisibleClick(Sender: TObject);
    procedure btnGuardarClick(Sender: TObject);
    procedure btnAddFotoClick(Sender: TObject);
    procedure btnAddQuitarFotoClick(Sender: TObject);
  private
    FGuardando: Boolean;
    FSeccionId: Integer;
    FUnidad: string;      // 'lb', 'paq' o 'u'
    FVisible: Boolean;
    FEditId: Integer;
    FFotoBlob: TJSObject;   // foto nueva elegida (ya reducida), pendiente de subir
    FFotoNueva: string;     // URL de esa foto una vez subida (por si falla el guardado y se reintenta)
    FFotoUrl: string;       // foto que ya tenía el producto (al editar)
    FQuitarFoto: Boolean;   // se quitó la foto que tenía
    [async]
    procedure CargarParaEditar;
    procedure PonerVisible(Si: Boolean);
    [async]
    procedure CargarSecciones;
    [async]
    procedure Guardar;
    [async]
    procedure PonerFoto(Archivo: JSValue);
    procedure MostrarVistaPrevia(Si: Boolean);
    procedure PonerVistaUrl(const Url: string);
    procedure MarcarSeccion(Id: Integer);
    procedure PonerUnidad(const Tipo: string);
    procedure PonerLibras(const Valor: string);
    procedure Recalcular;
    procedure MostrarError(const Msg: string);
    procedure OcultarError;
    procedure Ocupado(Si: Boolean);
  public
  end;

var
  Form4: TForm4;

implementation

uses
  uShell, uNavegacion, uInventarioService, uDom;

{$R *.dfm}

{ ---------- utilidades ---------- }

function Num(El: TJSElement): Double;
begin
  Result := StrToFloatDef(string(TJSHTMLInputElement(El).value), 0);
end;

procedure PonerNum(El: TJSElement; V: Double);
begin
  if V = 0 then
    TJSHTMLInputElement(El).value := ''
  else
    TJSHTMLInputElement(El).value := Numero(V, 3);
end;

function Cup(V: Double): string;
begin
  Result := FloatToStr(Round(V * 100) / 100) + ' CUP';
end;

// Reduce la foto del teléfono a un JPEG de máx. 'Lado' px (una foto de 4 MB queda en ~100 KB)
function ReducirFoto(Archivo: JSValue; Lado: Integer; Calidad: Double): TJSPromise;
begin
  asm
    Result = new Promise(function (resolve) {
      var url = URL.createObjectURL(Archivo);
      var img = new Image();
      img.onload = function () {
        var w = img.naturalWidth, h = img.naturalHeight;
        var k = Math.min(1, Lado / Math.max(w, h));
        var c = document.createElement('canvas');
        c.width = Math.round(w * k);
        c.height = Math.round(h * k);
        c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
        URL.revokeObjectURL(url);
        c.toBlob(function (b) { resolve(b); }, 'image/jpeg', Calidad);
      };
      img.onerror = function () { URL.revokeObjectURL(url); resolve(null); };
      img.src = url;
    });
  end;
end;

// Un solo clic para las secciones y las sugerencias (se crean por código)
function AlClicAgregar(Event: TJSEvent): Boolean;
var
  El: TJSElement;
  Pantalla: TForm4;
begin
  Result := True;
  if not (TShell.Actual is TForm4) then Exit;
  Pantalla := TForm4(TShell.Actual);

  El := Ancestro(TJSElement(Event.target), '[data-sec]');
  if El <> nil then
  begin
    Pantalla.MarcarSeccion(StrToIntDef(string(El.getAttribute('data-sec')), 0));
    Exit;
  end;

  El := Ancestro(TJSElement(Event.target), '[data-h]');
  if El <> nil then
    Pantalla.PonerLibras(string(El.getAttribute('data-h')));
end;

// Cada vez que se escribe en cualquier campo se recalcula costo y ganancia
function AlEscribirAgregar(Event: TJSEvent): Boolean;
begin
  Result := True;
  if TShell.Actual is TForm4 then
    TForm4(TShell.Actual).Recalcular;
end;

// Se eligió una foto (cámara o galería) en el input oculto
function AlElegirFoto(Event: TJSEvent): Boolean;
var
  Archivo: JSValue;
begin
  Result := True;
  if not (TShell.Actual is TForm4) then Exit;
  asm
    Archivo = (Event.target.files && Event.target.files[0]) ? Event.target.files[0] : null;
    Event.target.value = '';      // así se puede elegir la misma foto otra vez
  end;
  if isNull(Archivo) or isUndefined(Archivo) then Exit;
  TForm4(TShell.Actual).PonerFoto(Archivo);
end;

{ ---------- pantalla ---------- }

procedure TForm4.WebFormCreate(Sender: TObject);
begin
  TShell.Activar('inventario');   // la barra inferior sigue marcando Inventario
  TShell.Actual := Self;
  FVisible := True;

  FEditId := TShell.EditarId;
  TShell.EditarId := 0;
  if FEditId > 0 then
  begin
    document.querySelector('#divAgregar .who b').textContent := 'Editar producto';
    lblAddGuardar.ElementHandle.textContent := 'Guardar cambios';
  end;

  btnAddGuardar.OnClick := btnGuardarClick;
  btnAddUniLb.OnClick := btnAddUniLbClick;
  btnAddUniPaq.OnClick := btnUniPaqClick;
  btnAddUniU.OnClick := btnAddUniUClick;
  btnAddVisible.OnClick := btnVisibleClick;
  btnAddCancelar.OnClick := btnAddCancelarClick;
  btnAddVolver.OnClick := btnAddVolverClick;
  btnAddFoto.OnClick := btnAddFotoClick;
  btnAddCambiarFoto.OnClick := btnAddFotoClick;
  btnAddQuitarFoto.OnClick := btnAddQuitarFotoClick;

  PonerUnidad('lb');
  Recalcular;
  divAgregar.ElementHandle.addEventListener('click', @AlClicAgregar);
  divAgregar.ElementHandle.addEventListener('input', @AlEscribirAgregar);
  document.getElementById('edtAddFoto').addEventListener('change', @AlElegirFoto);
  CargarSecciones;
end;

procedure TForm4.CargarSecciones;
var
  R: TResultadoSecciones;
  Html: string;
  i: Integer;
begin
  R := await(TResultadoSecciones, TInventarioService.CargarSecciones);
  if not R.Ok then
  begin
    MostrarError(R.Error);
    Exit;
  end;
  if Length(R.Items) = 0 then
  begin
    MostrarError('No hay secciones. Crea al menos una antes de agregar productos.');
    Exit;
  end;

  Html := '';
  for i := 0 to High(R.Items) do
    Html := Html + '<button type="button" data-sec="' + IntToStr(R.Items[i].Id) + '">'
      + Esc(R.Items[i].Nombre) + '</button>';
  divAddSeccion.ElementHandle.innerHTML := Html;
  MarcarSeccion(R.Items[0].Id);
  if FEditId > 0 then
    CargarParaEditar;
end;

procedure TForm4.PonerVisible(Si: Boolean);
begin
  FVisible := Si;
  PonerClase(btnAddVisible.ElementHandle, 'on', Si);
  if Si then
    btnAddVisible.ElementHandle.setAttribute('aria-checked', 'true')
  else
    btnAddVisible.ElementHandle.setAttribute('aria-checked', 'false');
end;

procedure TForm4.CargarParaEditar;
var
  RP: TResultadoProductos;
  P: TProducto;
  i: Integer;
begin
  RP := await(TResultadoProductos, TInventarioService.CargarProductos);
  if not RP.Ok then
  begin
    MostrarError(RP.Error);
    Exit;
  end;
  P := nil;
  for i := 0 to High(RP.Items) do
    if RP.Items[i].Id = FEditId then
      P := RP.Items[i];
  if P = nil then
  begin
    MostrarError('No se encontró el producto.');
    Exit;
  end;

  edtAddNombre.Text := P.Nombre;
  edtAddNota.Text := P.Nota;
  MarcarSeccion(P.SeccionId);
  if P.TipoVenta = 'paquete_peso' then
    PonerUnidad('paq')
  else if P.TipoVenta = 'unidad' then
    PonerUnidad('u')
  else
    PonerUnidad('lb');
  PonerNum(edtLibras.ElementHandle, P.LibrasPorPaquete);
  PonerNum(edtAddCosto.ElementHandle, P.Costo);
  PonerNum(edtAddExtra.ElementHandle, P.CostoExtra);
  PonerNum(edtAddInsumo.ElementHandle, P.Insumo);
  PonerNum(edtAddPrecio.ElementHandle, P.Precio);
  PonerNum(edtAddStock.ElementHandle, P.Stock);
  PonerVisible(P.Visible);

  FFotoUrl := P.FotoUrl;
  if P.FotoUrl <> '' then
    PonerVistaUrl(P.FotoUrl);
  Recalcular;
end;

procedure TForm4.MarcarSeccion(Id: Integer);
var
  Botones: TJSNodeList;
  i: Integer;
  B: TJSElement;
begin
  FSeccionId := Id;
  Botones := divAddSeccion.ElementHandle.querySelectorAll('button');
  for i := 0 to Botones.length - 1 do
  begin
    B := TJSElement(Botones.item(i));
    PonerClase(B, 'on', string(B.getAttribute('data-sec')) = IntToStr(Id));
  end;
end;

procedure TForm4.PonerUnidad(const Tipo: string);
begin
  FUnidad := Tipo;
  PonerClase(btnAddUniLb.ElementHandle, 'on', Tipo = 'lb');
  PonerClase(btnAddUniPaq.ElementHandle, 'on', Tipo = 'paq');
  PonerClase(btnAddUniU.ElementHandle, 'on', Tipo = 'u');
  lblUnidad.ElementHandle.textContent := Tipo;
  Mostrar(divPaquete.ElementHandle, Tipo = 'paq');
end;

procedure TForm4.PonerLibras(const Valor: string);
begin
  TJSHTMLInputElement(edtLibras.ElementHandle).value := Valor;
end;

procedure TForm4.Recalcular;
var
  Total, Neto: Double;
  ElTotal, ElNeto: TJSElement;
begin
  ElTotal := document.getElementById('lblAddCostoTotal');
  ElNeto := document.getElementById('lblAddNeto');
  if (ElTotal = nil) or (ElNeto = nil) then Exit;

  Total := Num(edtAddCosto.ElementHandle) + Num(edtAddExtra.ElementHandle)
    + Num(edtAddInsumo.ElementHandle);
  Neto := Num(edtAddPrecio.ElementHandle) - Total;
  ElTotal.textContent := Cup(Total);
  ElNeto.textContent := Cup(Neto);
  PonerClase(ElNeto, 'ok', Neto >= 0);
  PonerClase(ElNeto, 'neg', Neto < 0);
end;

{ ---------- foto ---------- }

// Con vista previa se oculta el cuadro de "Agregar foto", y al revés
procedure TForm4.MostrarVistaPrevia(Si: Boolean);
begin
  Mostrar(divAddFotoPrev.ElementHandle, Si);
  Mostrar(btnAddFoto.ElementHandle, not Si);
end;

procedure TForm4.PonerVistaUrl(const Url: string);
begin
  asm
    document.getElementById('imgAddFoto').src = Url;
  end;
  MostrarVistaPrevia(True);
end;

procedure TForm4.btnAddFotoClick(Sender: TObject);
begin
  asm
    document.getElementById('edtAddFoto').click();
  end;
end;

procedure TForm4.PonerFoto(Archivo: JSValue);
var
  Foto: TJSObject;
begin
  Foto := await(TJSObject, ReducirFoto(Archivo, 800, 0.8));
  if Foto = nil then
  begin
    MostrarError('No se pudo leer la foto. Prueba con otra.');
    Exit;
  end;
  OcultarError;
  FFotoBlob := Foto;
  FFotoNueva := '';
  FQuitarFoto := False;
  asm
    var img = document.getElementById('imgAddFoto');
    if (window.__fotoPrev) URL.revokeObjectURL(window.__fotoPrev);
    window.__fotoPrev = URL.createObjectURL(Foto);
    img.src = window.__fotoPrev;
  end;
  MostrarVistaPrevia(True);
end;

procedure TForm4.btnAddQuitarFotoClick(Sender: TObject);
begin
  FFotoBlob := nil;
  FFotoNueva := '';
  if FFotoUrl <> '' then
    FQuitarFoto := True;            // al guardar, el producto queda sin foto
  asm
    document.getElementById('imgAddFoto').removeAttribute('src');
  end;
  MostrarVistaPrevia(False);
end;

{ ---------- eventos ---------- }

procedure TForm4.btnUniLbClick(Sender: TObject);
begin
  PonerUnidad('lb');
end;

procedure TForm4.btnAddUniLbClick(Sender: TObject);
begin
  PonerUnidad('lb');
end;

procedure TForm4.btnUniPaqClic(Sender: TObject);
begin
  PonerUnidad('paq');
end;

procedure TForm4.btnUniPaqClick(Sender: TObject);
begin
  PonerUnidad('paq');
end;

procedure TForm4.btnAddUniUClick(Sender: TObject);
begin
  PonerUnidad('u');
end;

procedure TForm4.btnVisibleClick(Sender: TObject);
begin
  PonerVisible(not FVisible);
end;

procedure TForm4.btnGuardarClick(Sender: TObject);
begin
  if Sender <> btnAddGuardar then Exit;
  Guardar;
end;

procedure TForm4.Guardar;
var
  P: TProductoNuevo;
  R: TResultado;
  RF: TResultadoFoto;
begin
  if FGuardando then Exit;
  OcultarError;

  P.SeccionId := FSeccionId;
  P.Nombre := Trim(edtAddNombre.Text);
  P.Nota := Trim(edtAddNota.Text);
  P.TipoVenta := FUnidad;
  P.LibrasPorPaquete := Num(edtLibras.ElementHandle);
  P.Costo := Num(edtAddCosto.ElementHandle);
  P.CostoExtra := Num(edtAddExtra.ElementHandle);
  P.Insumo := Num(edtAddInsumo.ElementHandle);
  P.Precio := Num(edtAddPrecio.ElementHandle);
  P.Stock := Num(edtAddStock.ElementHandle);
  P.Visible := FVisible;
  P.FotoUrl := '';
  P.QuitarFoto := FQuitarFoto;

  if P.SeccionId = 0 then
  begin
    MostrarError('Elige una sección.');
    Exit;
  end;
  if P.Nombre = '' then
  begin
    MostrarError('Escribe el nombre del producto.');
    Exit;
  end;
  if (P.TipoVenta = 'paq') and (P.LibrasPorPaquete <= 0) then
  begin
    MostrarError('Indica cuántas libras trae cada paquete.');
    Exit;
  end;
  if (P.Costo < 0) or (P.CostoExtra < 0) or (P.Insumo < 0) then
  begin
    MostrarError('Los costos no pueden ser negativos.');
    Exit;
  end;
  if P.Precio <= 0 then
  begin
    MostrarError('El precio de venta debe ser mayor que cero.');
    Exit;
  end;
  if P.Stock < 0 then
  begin
    MostrarError('El stock no puede ser negativo.');
    Exit;
  end;

  FGuardando := True;
  Ocupado(True);

  // 1) la foto nueva se sube primero (si ya se subió en un intento anterior, no se repite)
  if (FFotoBlob <> nil) and (FFotoNueva = '') then
  begin
    RF := await(TResultadoFoto, TInventarioService.SubirFoto(FFotoBlob));
    if not RF.Ok then
    begin
      Ocupado(False);
      FGuardando := False;
      MostrarError(RF.Error + ' Puedes quitar la foto y guardar el producto sin ella.');
      Exit;
    end;
    FFotoNueva := RF.Url;
  end;
  P.FotoUrl := FFotoNueva;

  // 2) el producto
  if FEditId > 0 then
    R := await(TResultado, TInventarioService.ActualizarProducto(FEditId, P))
  else
    R := await(TResultado, TInventarioService.CrearProducto(P));
  Ocupado(False);
  FGuardando := False;

  if R.Ok then
  begin
    // la foto vieja ya no sirve si se cambió o se quitó
    if (FFotoUrl <> '') and ((P.FotoUrl <> '') or FQuitarFoto) then
      TInventarioService.BorrarFoto(FFotoUrl);
    if FEditId > 0 then
      TShell.Aviso := 'Producto actualizado'
    else
      TShell.Aviso := 'Producto guardado en inventario';
    TNavegacion.IrARuta('inventario');
  end
  else
    MostrarError(R.Error);
end;

procedure TForm4.Ocupado(Si: Boolean);
begin
  btnAddGuardar.Enabled := not Si;
  if Si then
    lblAddGuardar.ElementHandle.textContent := 'Guardando...'
  else if FEditId > 0 then
    lblAddGuardar.ElementHandle.textContent := 'Guardar cambios'
  else
    lblAddGuardar.ElementHandle.textContent := 'Guardar producto';
end;

procedure TForm4.MostrarError(const Msg: string);
begin
  lblAddError.ElementHandle.textContent := Msg;
  Mostrar(lblAddError.ElementHandle, True);
end;

procedure TForm4.OcultarError;
begin
  Mostrar(lblAddError.ElementHandle, False);
end;

procedure TForm4.btnAddCancelarClick(Sender: TObject);
begin
  TNavegacion.IrARuta('inventario');
end;

procedure TForm4.btnAddVolverClick(Sender: TObject);
begin
  TNavegacion.IrARuta('inventario');
end;

end.
