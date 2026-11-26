unit fAddProduct;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, WEBLib.StdCtrls, Vcl.Controls, WEBLib.ExtCtrls,
  Vcl.StdCtrls, WEBLib.WebCtrls, uInventarioService;

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
    FJabas: TPesos;         // pesos de las jabas (solo productos por libra)
    FJabasListas: Boolean;  // False = no se pudieron cargar las jabas guardadas: no tocarlas
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
    procedure AgregarJaba;
    procedure QuitarJaba(I: Integer);
    procedure PintarJabas;
  public
  end;

var
  Form4: TForm4;

implementation

uses
  uShell, uNavegacion, uDom;

{$R *.dfm}

{ ---------- utilidades ---------- }

function SumaPesos(const A: TPesos): Double;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(A) do
    Result := Result + A[i];
end;

function Num(El: TJSElement): Double;
var
  S: string;
begin
  S := string(TJSHTMLInputElement(El).value);
  asm
    Result = parseFloat(String(S).replace(',', '.')) || 0;
  end;
end;

procedure PonerNum(El: TJSElement; V: Double);
begin
  asm
    El.value = (V === 0) ? '' : String(Math.round(V * 1000) / 1000);
  end;
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

// Un solo clic para las secciones, las sugerencias y las jabas (se crean por código)
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

  El := Ancestro(TJSElement(Event.target), '[data-addjaba]');
  if El <> nil then
  begin
    Pantalla.AgregarJaba;
    Exit;
  end;

  El := Ancestro(TJSElement(Event.target), '[data-deljaba]');
  if El <> nil then
  begin
    Pantalla.QuitarJaba(StrToIntDef(string(El.getAttribute('data-deljaba')), -1));
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
  FJabasListas := (FEditId = 0);   // al crear no hay jabas guardadas que proteger
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

  // los eventos se activan antes de nada, para que la pantalla responda siempre
  divAgregar.ElementHandle.addEventListener('click', @AlClicAgregar);
  divAgregar.ElementHandle.addEventListener('input', @AlEscribirAgregar);
  document.getElementById('edtAddFoto').addEventListener('change', @AlElegirFoto);

  PonerUnidad('lb');
  Recalcular;
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
  RJ: TResultadoJabas;
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

  // jabas que siguen sin vender (solo productos por libra)
  if P.TipoVenta <> 'peso' then
  begin
    FJabasListas := True;          // no tenía jabas: nada que proteger
    Exit;
  end;
  RJ := await(TResultadoJabas, TInventarioService.CargarJabas(FEditId));
  if RJ.Ok then
  begin
    SetLength(FJabas, Length(RJ.Items));
    for i := 0 to High(RJ.Items) do
      FJabas[i] := RJ.Items[i].Peso;
    FJabasListas := True;
    PintarJabas;
  end;
  // si falla, FJabasListas queda en False y al guardar no se tocan las jabas
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
var
  El: TJSElement;
  PasoStock: string;
begin
  FUnidad := Tipo;
  PonerClase(btnAddUniLb.ElementHandle, 'on', Tipo = 'lb');
  PonerClase(btnAddUniPaq.ElementHandle, 'on', Tipo = 'paq');
  PonerClase(btnAddUniU.ElementHandle, 'on', Tipo = 'u');
  lblUnidad.ElementHandle.textContent := Tipo;
  Mostrar(divPaquete.ElementHandle, Tipo = 'paq');
  El := document.getElementById('divJabas');
  if El <> nil then
    Mostrar(El, Tipo = 'lb');

  // el spin sube de 0.1 en 0.1 en libras, y de 1 en 1 en paquetes/unidades
  if Tipo = 'lb' then
    PasoStock := '0.1'
  else
    PasoStock := '1';
  asm
    var s = document.getElementById('edtAddStock');
    if (s) s.setAttribute('step', PasoStock);
    var j = document.getElementById('edtJabaPeso');
    if (j) j.setAttribute('step', '0.1');
  end;
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

{ ---------- jabas ---------- }

procedure TForm4.AgregarJaba;
var
  Inp: TJSElement;
  V: Double;
begin
  Inp := document.getElementById('edtJabaPeso');
  if Inp = nil then Exit;
  V := Num(Inp);
  if V <= 0 then
  begin
    MostrarError('Escribe el peso de la jaba.');
    Exit;
  end;
  OcultarError;
  SetLength(FJabas, Length(FJabas) + 1);
  FJabas[High(FJabas)] := V;
  TJSHTMLInputElement(Inp).value := '';
  PintarJabas;
  PonerNum(edtAddStock.ElementHandle, SumaPesos(FJabas));   // el stock = total de jabas
end;

procedure TForm4.QuitarJaba(I: Integer);
var
  k: Integer;
begin
  if (I < 0) or (I > High(FJabas)) then Exit;
  for k := I to High(FJabas) - 1 do
    FJabas[k] := FJabas[k + 1];
  SetLength(FJabas, Length(FJabas) - 1);
  PintarJabas;
  PonerNum(edtAddStock.ElementHandle, SumaPesos(FJabas));   // el stock = total de jabas
end;

procedure TForm4.PintarJabas;
var
  Html: string;
  Total: Double;
  i: Integer;
  Lista, Resumen: TJSElement;
begin
  Lista := document.getElementById('divJabaLista');
  Resumen := document.getElementById('lblJabaTotal');
  if (Lista = nil) or (Resumen = nil) then Exit;

  Html := '';
  Total := 0;
  for i := 0 to High(FJabas) do
  begin
    Total := Total + FJabas[i];
    Html := Html + '<button type="button" data-deljaba="' + IntToStr(i) + '">'
      + Numero(FJabas[i], 3) + ' lb &times;</button>';
  end;
  Lista.innerHTML := Html;
  if Length(FJabas) = 0 then
    Resumen.textContent := ''
  else
    Resumen.textContent := IntToStr(Length(FJabas)) + ' jabas - ' + Numero(Total, 3) + ' lb';

    // al crear, el stock se llena con la suma (editable); al editar no se toca
  if (FEditId = 0) and (Length(FJabas) > 0) then
    PonerNum(edtAddStock.ElementHandle, Total);
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
  P.Jabas := FJabas;
  P.TocarJabas := FJabasListas;

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

  // 2) el producto (y sus jabas)
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
    if R.Error <> '' then
      TShell.Aviso := R.Error                    // producto guardado pero fallaron las jabas
    else if FEditId > 0 then
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
