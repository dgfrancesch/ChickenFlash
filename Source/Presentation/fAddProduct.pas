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
  private
    FGuardando: Boolean;
    FSeccionId: Integer;
    FUnidad: string;      // 'lb', 'paq' o 'u'
    FVisible: Boolean;
    [async]
    procedure CargarSecciones;
    [async]
    procedure Guardar;
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
  uShell, uNavegacion, uInventarioService;

{$R *.dfm}

{ ---------- utilidades ---------- }

function Ancestro(El: TJSElement; const Selector: string): TJSElement;
begin
  asm
    Result = El.closest(Selector);
  end;
end;

function Esc(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function Num(El: TJSElement): Double;
begin
  Result := StrToFloatDef(string(TJSHTMLInputElement(El).value), 0);
end;

function Cup(V: Double): string;
begin
  Result := FloatToStr(Round(V * 100) / 100) + ' CUP';
end;

procedure Mostrar(El: TJSElement; Visible: Boolean);
begin
  if Visible then
    El.removeAttribute('hidden')
  else
    El.setAttribute('hidden', '');
end;

procedure PonerClase(El: TJSElement; const Clase: string; Si: Boolean);
begin
  if Si then
    El.classList.add(Clase)
  else
    El.classList.remove(Clase);
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

{ ---------- pantalla ---------- }

procedure TForm4.WebFormCreate(Sender: TObject);
begin
  TShell.Activar('inventario');   // la barra inferior sigue marcando Inventario
  TShell.Actual := Self;
  FVisible := True;

  btnAddGuardar.OnClick := btnGuardarClick;
  btnAddUniLb.OnClick := btnAddUniLbClick;
  btnAddUniPaq.OnClick := btnUniPaqClick;
  btnAddUniU.OnClick := btnAddUniUClick;
  btnAddVisible.OnClick := btnVisibleClick;
  btnAddCancelar.OnClick := btnAddCancelarClick;
  btnAddVolver.OnClick := btnAddVolverClick;

  PonerUnidad('lb');
  Recalcular;
  divAgregar.ElementHandle.addEventListener('click', @AlClicAgregar);
  divAgregar.ElementHandle.addEventListener('input', @AlEscribirAgregar);
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
  FVisible := not FVisible;
  PonerClase(btnAddVisible.ElementHandle, 'on', FVisible);
  if FVisible then
    btnAddVisible.ElementHandle.setAttribute('aria-checked', 'true')
  else
    btnAddVisible.ElementHandle.setAttribute('aria-checked', 'false');
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
  R := await(TResultado, TInventarioService.CrearProducto(P));
  Ocupado(False);
  FGuardando := False;

  if R.Ok then
  begin
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
