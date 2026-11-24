unit fInventory;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, WEBLib.StdCtrls, WEBLib.ExtCtrls, Vcl.Controls,
  Vcl.StdCtrls, WEBLib.WebCtrls, uInventarioService;

type
  TForm3 = class(TWebForm)
    divModal: TWebHTMLDiv;
    lblInicial: TWebHTMLDiv;
    lblRed: TWebHTMLSpan;
    divInvFiltros: TWebHTMLDiv;
    btnKpiBajo: TWebButton;
    btnAgregar: TWebButton;
    btnUniLb: TWebButton;
    btnEditarSecciones: TWebButton;
    btnEliminar: TWebButton;
    edtNombre: TWebEdit;
    btnVisible: TWebButton;
    btnQuitarFoto: TWebButton;
    btnFoto: TWebButton;
    divSheet: TWebHTMLDiv;
    lblEliminar: TWebHTMLSpan;
    btnCancelar: TWebButton;
    divSeccion: TWebHTMLDiv;
    lblGuardar: TWebHTMLSpan;
    lblModalTitulo: TWebLabel;
    divLista: TWebHTMLDiv;
    btnTodos: TWebButton;
    edtDetalle: TWebEdit;
    btnGuardar: TWebButton;
    imgFoto: TWebImageControl;
    edtPrecio: TWebSpinEdit;
    divToast: TWebHTMLDiv;
    divFotoPrev: TWebHTMLDiv;
    edtStock: TWebSpinEdit;
    btnCambiarFoto: TWebButton;
    btnUniPaq: TWebButton;
    btnKpiActivos: TWebButton;
    edtInvBuscar: TWebEdit;
    lblToast: TWebHTMLSpan;
    btnCerrar: TWebButton;
    divInventario: TWebHTMLDiv;
    divSecciones: TWebHTMLDiv;
    procedure WebFormCreate(Sender: TObject);
    procedure btnAgregarClick(Sender: TObject);
    procedure btnKpiActivosClick(Sender: TObject);
    procedure btnKpiBajoClick(Sender: TObject);
  private
    FSecciones: array of TSeccion;
    FProductos: array of TProducto;
    FSeccionId: Integer;          // 0 = todas las secciones
    FFiltroKpi: string;           // '' = ninguno, 'activos' o 'bajo'
        FBusqueda: string;            // texto buscado, sin tildes y en minúsculas
    procedure edtInvBuscarChange(Sender: TObject);
    [async]
    procedure Cargar;
    procedure PintarSecciones;
    procedure PintarLista;
    procedure PintarKpis;
    procedure MarcarChips;
    procedure MarcarKpis;
    procedure FiltrarSeccion(Id: Integer);
    procedure AlternarKpi(const Filtro: string);
    function Coincide(P: TProducto): Boolean;
    function NombreSeccion(Id: Integer): string;
    procedure MostrarAviso(const Msg: string);
        [async]
    procedure AjustarStock(Id: Integer; Valor: Double; Relativo: Boolean);
  public
  end;

var
  Form3: TForm3;

implementation

uses
  uShell, uSession, uNavegacion, uDom;

{$R *.dfm}

const
  LIMITE_STOCK_BAJO = 8;

{ ---------- tarjeta de producto ---------- }

function UnidadDe(P: TProducto): string;
begin
  if P.TipoVenta = 'paquete_peso' then
    Result := 'paq'
  else if P.TipoVenta = 'unidad' then
    Result := 'u'
  else
    Result := 'lb';
end;

function DetalleDe(P: TProducto): string;
begin
  if P.TipoVenta = 'paquete_peso' then
    Result := 'Paquete ' + Numero(P.LibrasPorPaquete, 3) + ' lb'
  else if P.TipoVenta = 'unidad' then
    Result := 'Por unidad'
  else
    Result := 'Por libra';
end;

function IconoDe(P: TProducto): string;
begin
  if P.FotoUrl <> '' then
    Result := '<img class="thumb" src="' + Esc(P.FotoUrl) + '" alt="" loading="lazy" ' +
      'onerror="this.outerHTML=&quot;<svg class=i><use href=#i-box></use></svg>&quot;">'
  else
    Result := '<svg class="i"><use href="#i-box"></use></svg>';
end;

function TarjetaProducto(P: TProducto; const Seccion: string): string;
var
  ClaseItem, ClaseStock, Insignias: string;
begin
  ClaseItem := 'item';
  Insignias := '';
  if Seccion <> '' then
    Insignias := '<span class="badge">' + Esc(Seccion) + '</span>';
  if not P.Visible then
  begin
    ClaseItem := 'item is-hidden';
    Insignias := Insignias + '<span class="badge off">Oculto</span>';
  end;

  ClaseStock := 'stock';
  if P.Stock <= 0 then
    ClaseStock := 'stock zero'
  else if P.Stock <= LIMITE_STOCK_BAJO then
    ClaseStock := 'stock low';

  Result :=
    '<div class="' + ClaseItem + '" data-id="' + IntToStr(P.Id) + '">' +
      '<div class="item-top">' +
                '<div class="ico">' + IconoDe(P) + '</div>' +
        '<div class="info">' +
          '<div class="title-row"><b>' + Esc(P.Nombre) + '</b>' + Insignias + '</div>' +
          '<div class="meta">' + Esc(DetalleDe(P)) + '</div>' +
          '<div class="price-row">' +
            '<span class="price">' + Numero(P.Precio, 2) + ' CUP</span>' +
            '<span class="' + ClaseStock + '">Stock: ' + Numero(P.Stock, 3) + ' ' + UnidadDe(P) + '</span>' +
          '</div>' +
        '</div>' +
      '</div>' +
      '<div class="item-actions">' +
        '<div class="stock-ctl">' +
          '<span class="stock-lbl">Ajustar:</span>' +
          '<div class="pill">' +
            '<button class="rb" type="button" data-accion="menos" aria-label="Quitar"><svg class="i"><use href="#i-minus"></use></svg></button>' +
            '<input class="q" type="text" inputmode="decimal" data-accion="cantidad" value="' + Numero(P.Stock, 3) + '" aria-label="Cantidad">' +
            '<button class="rb g" type="button" data-accion="mas" aria-label="Agregar"><svg class="i"><use href="#i-plus"></use></svg></button>' +
          '</div>' +
        '</div>' +
        '<button class="edit-btn" type="button" data-accion="editar"><svg class="i"><use href="#i-edit"></use></svg>Editar</button>' +
      '</div>' +
    '</div>';
end;

{ ---------- clic en los chips de sección ---------- }

function AlClicLista(Event: TJSEvent): Boolean;
var
  Btn, Item: TJSElement;
  Accion: string;
  Id: Integer;
begin
  Result := True;
  Btn := Ancestro(TJSElement(Event.target), '[data-accion]');
  if Btn = nil then Exit;
  Item := Ancestro(Btn, '.item[data-id]');
  if Item = nil then Exit;
  Id := StrToIntDef(string(Item.getAttribute('data-id')), 0);
  Accion := string(Btn.getAttribute('data-accion'));

  if Accion = 'editar' then
  begin
    TShell.EditarId := Id;
    TNavegacion.IrARuta('agregar');
  end
  else if not (TShell.Actual is TForm3) then Exit
  else if Accion = 'mas' then
    TForm3(TShell.Actual).AjustarStock(Id, 1, True)
  else if Accion = 'menos' then
    TForm3(TShell.Actual).AjustarStock(Id, -1, True);
end;

// Al escribir una cantidad a mano en el cuadro del medio
function AlCambiarLista(Event: TJSEvent): Boolean;
var
  Inp, Item: TJSElement;
  Txt: string;
begin
  Result := True;
  Inp := Ancestro(TJSElement(Event.target), 'input[data-accion="cantidad"]');
  if Inp = nil then Exit;
  Item := Ancestro(Inp, '.item[data-id]');
  if Item = nil then Exit;
  if not (TShell.Actual is TForm3) then Exit;
  Txt := StringReplace(string(TJSHTMLInputElement(Inp).value), ',', '.', []);
  TForm3(TShell.Actual).AjustarStock(
    StrToIntDef(string(Item.getAttribute('data-id')), 0),
    StrToFloatDef(Txt, 0), False);
end;

function AlClicFiltros(Event: TJSEvent): Boolean;
var
  El: TJSElement;
begin
  Result := True;
  if not (TShell.Actual is TForm3) then Exit;

  El := Ancestro(TJSElement(Event.target), '[data-sec]');
  if El <> nil then
  begin
    TForm3(TShell.Actual).FiltrarSeccion(StrToIntDef(string(El.getAttribute('data-sec')), 0));
    Exit;
  end;

  El := Ancestro(TJSElement(Event.target), '#btnTodos');
  if El <> nil then
    TForm3(TShell.Actual).FiltrarSeccion(0);
      El := Ancestro(TJSElement(Event.target), '#btnEditarSecciones');
  if El <> nil then
    TNavegacion.IrARuta('secciones');
end;

// Quita el foco de cualquier campo (en el telefono evita que se abra el teclado solo).
// Se repite porque el formulario puede enfocar un campo al terminar de crearse.
procedure QuitarFoco;
begin
  asm
    var q = function () {
      var a = document.activeElement;
      if (a && a !== document.body && a.blur) { a.blur(); }
    };
    q();
    setTimeout(q, 0);
    setTimeout(q, 200);
  end;
end;

{ ---------- pantalla ---------- }

procedure TForm3.WebFormCreate(Sender: TObject);
begin
  lblInicial.HTML.Text := UpperCase(Copy(TSession.UserName, 1, 1));
  TShell.Activar('inventario');
  TShell.Actual := Self;
  if TShell.Aviso <> '' then
  begin
    MostrarAviso(TShell.Aviso);
    TShell.Aviso := '';
  end;

  btnAgregar.OnClick := btnAgregarClick;
  btnKpiActivos.OnClick := btnKpiActivosClick;
  btnKpiBajo.OnClick := btnKpiBajoClick;
    edtInvBuscar.OnChange := edtInvBuscarChange;
  divInvFiltros.ElementHandle.addEventListener('click', @AlClicFiltros);
    divLista.ElementHandle.addEventListener('click', @AlClicLista);
      divLista.ElementHandle.addEventListener('change', @AlCambiarLista);
  QuitarFoco;                                  // que el buscador no quede enfocado
  Cargar;
end;

procedure TForm3.Cargar;
var
  RS: TResultadoSecciones;
  RP: TResultadoProductos;
begin
  divLista.ElementHandle.innerHTML := '<div class="empty">Cargando productos...</div>';

  RS := await(TResultadoSecciones, TInventarioService.CargarSecciones);
  if TShell.Actual <> Self then Exit;          // ya saliste de esta pantalla
  if not RS.Ok then
  begin
    divLista.ElementHandle.innerHTML := '<div class="empty">' + Esc(RS.Error) + '</div>';
    Exit;
  end;

  RP := await(TResultadoProductos, TInventarioService.CargarProductos);
  if TShell.Actual <> Self then Exit;
  if not RP.Ok then
  begin
    divLista.ElementHandle.innerHTML := '<div class="empty">' + Esc(RP.Error) + '</div>';
    Exit;
  end;

  FSecciones := RS.Items;
  FProductos := RP.Items;
  FSeccionId := 0;
  FFiltroKpi := '';
  PintarSecciones;
  MarcarChips;
  MarcarKpis;
  PintarKpis;
  PintarLista;
end;

procedure TForm3.PintarSecciones;
var
  Html: string;
  i: Integer;
begin
  Html := '';
  for i := 0 to High(FSecciones) do
    Html := Html + '<button type="button" data-sec="' + IntToStr(FSecciones[i].Id) + '">'
      + Esc(FSecciones[i].Nombre) + '</button>';
  divSecciones.ElementHandle.innerHTML := Html;
end;

procedure TForm3.MarcarChips;
var
  Botones: TJSNodeList;
  i: Integer;
  B: TJSElement;
begin
  PonerClase(btnTodos.ElementHandle, 'on', FSeccionId = 0);
  Botones := divSecciones.ElementHandle.querySelectorAll('button');
  for i := 0 to Botones.length - 1 do
  begin
    B := TJSElement(Botones.item(i));
    PonerClase(B, 'on', string(B.getAttribute('data-sec')) = IntToStr(FSeccionId));
  end;
end;

procedure TForm3.FiltrarSeccion(Id: Integer);
begin
  FSeccionId := Id;
  MarcarChips;
  PintarLista;
end;

function TForm3.NombreSeccion(Id: Integer): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(FSecciones) do
    if FSecciones[i].Id = Id then
    begin
      Result := FSecciones[i].Nombre;
      Exit;
    end;
end;

function Normalizar(const S: string): string;
begin
  asm
    Result = String(S).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  end;
end;

// Un producto se muestra si cumple la sección elegida y el filtro de los contadores
function TForm3.Coincide(P: TProducto): Boolean;
begin
  Result := (FSeccionId = 0) or (P.SeccionId = FSeccionId);
  if not Result then Exit;
  if FFiltroKpi = 'activos' then
    Result := P.Visible
  else if FFiltroKpi = 'bajo' then
    Result := P.Visible and (P.Stock <= LIMITE_STOCK_BAJO);
  if not Result then Exit;
  if FBusqueda <> '' then
    Result := Pos(FBusqueda, Normalizar(P.Nombre)) > 0;
end;
procedure TForm3.edtInvBuscarChange(Sender: TObject);
begin
  FBusqueda := Normalizar(Trim(edtInvBuscar.Text));
  PintarLista;
end;

procedure TForm3.MarcarKpis;
begin
  PonerClase(btnKpiActivos.ElementHandle, 'active', FFiltroKpi = 'activos');
  PonerClase(btnKpiBajo.ElementHandle, 'active-low', FFiltroKpi = 'bajo');
end;

// Tocar el contador activo otra vez quita el filtro
procedure TForm3.AlternarKpi(const Filtro: string);
begin
  if FFiltroKpi = Filtro then
    FFiltroKpi := ''
  else
    FFiltroKpi := Filtro;
  MarcarKpis;
  PintarLista;
end;

procedure TForm3.btnKpiActivosClick(Sender: TObject);
begin
  AlternarKpi('activos');
end;

procedure TForm3.btnKpiBajoClick(Sender: TObject);
begin
  AlternarKpi('bajo');
end;

procedure TForm3.PintarLista;
var
  Html: string;
  i, N: Integer;
  P: TProducto;
begin
  Html := '';
  N := 0;
  for i := 0 to High(FProductos) do
  begin
    P := FProductos[i];
    if not Coincide(P) then Continue;
    Html := Html + TarjetaProducto(P, NombreSeccion(P.SeccionId));
    Inc(N);
  end;

  if N = 0 then
  begin
    if Length(FProductos) = 0 then
      Html := '<div class="empty">Aún no hay productos. Toca Agregar para crear el primero.</div>'
    else
      Html := '<div class="empty">No hay productos con este filtro.</div>';
  end;
  divLista.ElementHandle.innerHTML := Html;
end;

procedure TForm3.AjustarStock(Id: Integer; Valor: Double; Relativo: Boolean);
var
  P: TProducto;
  i: Integer;
  Nuevo, Anterior: Double;
  R: TResultado;
begin
  P := nil;
  for i := 0 to High(FProductos) do
    if FProductos[i].Id = Id then
      P := FProductos[i];
  if P = nil then Exit;

  Anterior := P.Stock;
  if Relativo then
    Nuevo := P.Stock + Valor
  else
    Nuevo := Valor;
  if Nuevo < 0 then Nuevo := 0;
  if P.TipoVenta = 'peso' then
    Nuevo := Round(Nuevo * 1000) / 1000
  else
    Nuevo := Round(Nuevo);                 // paquetes y unidades enteros

  if Nuevo = Anterior then
  begin
    PintarLista;                           // restaura el texto del cuadro
    Exit;
  end;

  P.Stock := Nuevo;                        // se ve al instante
  PintarKpis;
  PintarLista;

  R := await(TResultado, TInventarioService.ActualizarStock(Id, Nuevo));
  if TShell.Actual <> Self then Exit;
  if not R.Ok then
  begin
    P.Stock := Anterior;                   // si falla, vuelve al valor anterior
    PintarKpis;
    PintarLista;
    MostrarAviso(R.Error);
  end;
end;

// Activos = productos visibles; Stock bajo = visibles con stock <= LIMITE_STOCK_BAJO
procedure TForm3.PintarKpis;
var
  Activos, Bajos, i: Integer;
  ElActivos, ElBajo: TJSElement;
begin
  Activos := 0;
  Bajos := 0;
  for i := 0 to High(FProductos) do
    if FProductos[i].Visible then
    begin
      Inc(Activos);
      if FProductos[i].Stock <= LIMITE_STOCK_BAJO then
        Inc(Bajos);
    end;

  ElActivos := document.getElementById('lblKpiActivos');
  ElBajo := document.getElementById('lblKpiBajo');
  if ElActivos <> nil then ElActivos.textContent := IntToStr(Activos);
  if ElBajo <> nil then ElBajo.textContent := IntToStr(Bajos);
end;

procedure TForm3.btnAgregarClick(Sender: TObject);
begin
  TNavegacion.IrARuta('agregar');
end;

procedure TForm3.MostrarAviso(const Msg: string);
var
  El: TJSElement;
begin
  lblToast.ElementHandle.textContent := Msg;
  El := divToast.ElementHandle;
  El.removeAttribute('hidden');
  asm
    setTimeout(function(){ El.setAttribute('hidden', ''); }, 2200);
  end;
end;

end.
