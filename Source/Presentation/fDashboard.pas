unit fDashboard;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, Vcl.StdCtrls, WEBLib.StdCtrls, Vcl.Controls,
  WEBLib.WebCtrls, uInventarioService;

type
  TForm2 = class(TWebForm)
    lblInicial: TWebHTMLDiv;
    divVenta: TWebHTMLDiv;
    divProductos: TWebHTMLDiv;
    btnVaciar: TWebButton;
    lblRed: TWebHTMLSpan;
    divFiltros: TWebHTMLDiv;
    dashboard: TWebHTMLDiv;
    btnCobrar: TWebButton;
    lblVentaAviso: TWebLabel;
    edtBuscar: TWebEdit;
    procedure WebFormCreate(Sender: TObject);
    procedure btnVaciarClick(Sender: TObject);
    procedure btnCobrarClick(Sender: TObject);
  private
    FSecciones: array of TSeccion;
    FProductos: array of TProducto;
    FQ: array of Double;          // cantidad en la venta de cada producto (mismo orden que FProductos)
    FJabas: array of TJaba;       // jabas disponibles (sin vender) de todos los productos
    FJabaSel: array of Boolean;   // jaba elegida para la venta (mismo orden que FJabas)
    FSeccionId: Integer;          // 0 = todas las secciones
    FBusqueda: string;            // texto buscado, sin tildes y en minúsculas
    [async]
    procedure Cargar;
    [async]
    procedure CargarVentasHoy;
    function IndiceDe(Id: Integer): Integer;
    function TonoDe(SeccionId: Integer): Integer;
    function TieneJabas(ProductoId: Integer): Boolean;
    function IndiceJaba(Id: Integer): Integer;
    function CuentaJabas(ProductoId: Integer; SoloElegidas: Boolean): Integer;
    procedure RecalcularJabas(ProductoId: Integer);
    procedure LimpiarJabas(ProductoId: Integer);
    procedure AlternarJaba(Id: Integer);
    procedure ElegirJaba(ProductoId, Clave: Integer);
    procedure PonerJabas(Card: TJSElement; ProductoId: Integer);
    procedure PintarFiltros;
    procedure AgregarChip(const Nombre: string; Id: Integer);
    procedure MarcarFiltros;
    procedure FiltrarSeccion(Id: Integer);
    procedure Buscar(const Texto: string);
    procedure PintarProductos;
    procedure PintarVenta;
    procedure Repintar;
    procedure Accionar(Id: Integer; const Accion: string);
    procedure FijarCantidad(Id: Integer; Valor: Double);
    procedure RestaurarVenta;
  public
  end;

var
  Form2: TForm2;

implementation

uses
  uShell, uSession, uDom, uVentasService, uNavegacion, uAjustes;

{$R *.dfm}


{ ---------- utilidades ---------- }

function Por(const Id: string): TJSElement;
begin
  Result := document.getElementById(Id);
end;

function R2(V: Double): Double;
begin
  Result := Round(V * 100) / 100;
end;

function Normalizar(const S: string): string;
begin
  asm
    Result = String(S).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  end;
end;

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

// Las libras suben de 0.5 en 0.5; paquetes y unidades de 1 en 1
function Paso(P: TProducto): Double;
begin
  if P.TipoVenta = 'peso' then
    Result := 0.5
  else
    Result := 1;
end;

procedure PonerTexto(Raiz: TJSElement; const Selector, Texto: string);
var
  El: TJSElement;
begin
  El := Raiz.querySelector(Selector);
  if El <> nil then
    El.textContent := Texto;
end;

// Pone la foto sobre el ícono; si no carga, se oculta y queda el ícono
procedure PonerFoto(Raiz: TJSElement; const Url: string);
begin
  asm
    var img = Raiz.querySelector('.db-foto');
    if (img && Url) {
      img.addEventListener('error', function () { img.setAttribute('hidden', ''); });
      img.setAttribute('src', Url);
      img.removeAttribute('hidden');
    }
  end;
end;

// Dentro de .db-ctl: selector de cantidad si ya está en la venta, o botón Agregar
procedure PonerControl(Fila: TJSElement; Cantidad: Double; PuedeAgregar: Boolean);
var
  Ctl, Molde: TJSElement;
begin
  Ctl := Fila.querySelector('.db-ctl');
  if Ctl = nil then Exit;
  if Cantidad > 0 then
  begin
    Molde := Clonar('tplCantidad');
    TJSHTMLInputElement(Molde.querySelector('input')).value := Numero(Cantidad, 2);
    Ctl.appendChild(Molde);
  end
  else if PuedeAgregar then
    Ctl.appendChild(Clonar('tplAgregar'));
end;

{ ---------- eventos del HTML (se crean por código) ---------- }

function AlClicDash(Event: TJSEvent): Boolean;
var
  El, Fila: TJSElement;
begin
  Result := True;
  if not (TShell.Actual is TForm2) then Exit;

  El := Ancestro(TJSElement(Event.target), '[data-seccion]');
  if El <> nil then
  begin
    TForm2(TShell.Actual).FiltrarSeccion(StrToIntDef(string(El.getAttribute('data-seccion')), 0));
    Exit;
  end;

  // chip de peso: se agrega una jaba de ese peso a la venta
  El := Ancestro(TJSElement(Event.target), '[data-jabaw]');
  if El <> nil then
  begin
    TForm2(TShell.Actual).ElegirJaba(
      StrToIntDef(string(El.getAttribute('data-prod')), 0),
      StrToIntDef(string(El.getAttribute('data-jabaw')), 0));
    Exit;
  end;

  // papelera de una jaba en la venta actual
  El := Ancestro(TJSElement(Event.target), '[data-jaba]');
  if El <> nil then
  begin
    TForm2(TShell.Actual).AlternarJaba(StrToIntDef(string(El.getAttribute('data-jaba')), 0));
    Exit;
  end;

  El := Ancestro(TJSElement(Event.target), '[data-accion]');
  if El = nil then Exit;
  Fila := Ancestro(El, '[data-id]');
  if Fila = nil then Exit;
  TForm2(TShell.Actual).Accionar(
    StrToIntDef(string(Fila.getAttribute('data-id')), 0),
    string(El.getAttribute('data-accion')));
end;

// Cantidad escrita a mano
function AlCambiarDash(Event: TJSEvent): Boolean;
var
  Inp, Fila: TJSElement;
  Txt: string;
begin
  Result := True;
  if not (TShell.Actual is TForm2) then Exit;
  Inp := Ancestro(TJSElement(Event.target), 'input[data-accion="cantidad"]');
  if Inp = nil then Exit;
  Fila := Ancestro(Inp, '[data-id]');
  if Fila = nil then Exit;
  Txt := StringReplace(string(TJSHTMLInputElement(Inp).value), ',', '.', [rfReplaceAll]);
  TForm2(TShell.Actual).FijarCantidad(
    StrToIntDef(string(Fila.getAttribute('data-id')), 0),
    StrToFloatDef(Txt, 0));
end;

// Texto del buscador
function AlEscribirDash(Event: TJSEvent): Boolean;
var
  Inp: TJSElement;
begin
  Result := True;
  if not (TShell.Actual is TForm2) then Exit;
  Inp := Ancestro(TJSElement(Event.target), '#edtBuscar');
  if Inp = nil then Exit;
  TForm2(TShell.Actual).Buscar(string(TJSHTMLInputElement(Inp).value));
end;

// Al tocar el cuadro de cantidad se selecciona todo para escribir encima
function AlEnfocarDash(Event: TJSEvent): Boolean;
begin
  Result := True;
  asm
    var t = Event.target;
    if (t && t.classList && t.classList.contains('db-q')) t.select();
  end;
end;

// Enter confirma la cantidad escrita
function AlTeclaDash(Event: TJSEvent): Boolean;
begin
  Result := True;
  asm
    var t = Event.target;
    if (Event.key === 'Enter' && t && t.classList && t.classList.contains('db-q')) t.blur();
  end;
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

procedure TForm2.WebFormCreate(Sender: TObject);
var
  Nombre: string;
begin
  Nombre := TSession.UserName;
  Por('lblSaludo').textContent := 'Hola, ' + Nombre;
  lblInicial.ElementHandle.innerHTML := UpperCase(Copy(Nombre, 1, 1));
  TShell.Activar('vender');
  TShell.Actual := Self;

  btnVaciar.OnClick := btnVaciarClick;
  btnCobrar.OnClick := btnCobrarClick;
  dashboard.ElementHandle.addEventListener('click', @AlClicDash);
  dashboard.ElementHandle.addEventListener('change', @AlCambiarDash);
  dashboard.ElementHandle.addEventListener('input', @AlEscribirDash);
  dashboard.ElementHandle.addEventListener('focusin', @AlEnfocarDash);
  dashboard.ElementHandle.addEventListener('keydown', @AlTeclaDash);
  // Si se recargo en otra ruta (ej. #/cobrar), esta pantalla es Vender: se corrige la URL
  if TNavegacion.RutaActual <> 'vender' then
    TNavegacion.IrARuta('vender', True);
  QuitarFoco;                                  // que el buscador no quede enfocado
  Cargar;
end;

procedure TForm2.Cargar;
var
  RS: TResultadoSecciones;
  RP: TResultadoProductos;
  RJ: TResultadoJabas;
  i: Integer;
begin
  divProductos.ElementHandle.innerHTML :=
    '<div class="db-vacio-grid">Cargando productos...</div>';

  RS := await(TResultadoSecciones, TInventarioService.CargarSecciones);
  if TShell.Actual <> Self then Exit;          // ya saliste de esta pantalla
  if not RS.Ok then
  begin
    divProductos.ElementHandle.innerHTML :=
      '<div class="db-vacio-grid">' + Esc(RS.Error) + '</div>';
    Exit;
  end;

  RP := await(TResultadoProductos, TInventarioService.CargarProductos);
  if TShell.Actual <> Self then Exit;
  if not RP.Ok then
  begin
    divProductos.ElementHandle.innerHTML :=
      '<div class="db-vacio-grid">' + Esc(RP.Error) + '</div>';
    Exit;
  end;

  // jabas disponibles (si falla, los productos se venden por libra normal)
  RJ := await(TResultadoJabas, TInventarioService.CargarJabas(0));
  if TShell.Actual <> Self then Exit;

  FSecciones := RS.Items;
  FProductos := RP.Items;
  SetLength(FQ, Length(FProductos));
  for i := 0 to High(FQ) do
    FQ[i] := 0;

  if RJ.Ok then
    FJabas := RJ.Items
  else
    SetLength(FJabas, 0);
  SetLength(FJabaSel, Length(FJabas));
  for i := 0 to High(FJabaSel) do
    FJabaSel[i] := False;

  FSeccionId := 0;
  RestaurarVenta;                              // si vuelves desde Cobrar, la venta sigue armada
  PintarFiltros;
  Repintar;
  CargarVentasHoy;
end;

// Recupera la venta guardada en sessionStorage ('venta') al volver de la pantalla de cobro
procedure TForm2.RestaurarVenta;
var
  Txt: string;
  Venta, Item: TJSObject;
  Items: TJSArray;
  j, k, m: Integer;
  V: Double;
begin
  asm
    Txt = sessionStorage.getItem('venta') || '';
  end;
  if Txt = '' then Exit;
  try
    Venta := TJSObject(TJSJSON.parse(Txt));
    Items := TJSArray(Venta['items']);
    for j := 0 to Items.length - 1 do
    begin
      Item := TJSObject(Items[j]);
      k := IndiceDe(Integer(Item['id']));
      if k < 0 then Continue;

      // producto con jabas: cada línea es una jaba elegida
      if TieneJabas(FProductos[k].Id) then
      begin
        if not (isNull(Item['jaba_id']) or isUndefined(Item['jaba_id'])) then
        begin
          m := IndiceJaba(Integer(Item['jaba_id']));
          if m >= 0 then
          begin
            FJabaSel[m] := True;
            RecalcularJabas(FProductos[k].Id);
          end;
        end;
        Continue;
      end;

      V := Double(Item['cantidad']);
      if V > FProductos[k].Stock then V := FProductos[k].Stock;
      if V > 0 then FQ[k] := V;
    end;
  except
  end;
end;

procedure TForm2.CargarVentasHoy;
var
  R: TResultadoMonto;
begin
  R := await(TResultadoMonto, TVentasService.VentasDeHoy);
  if TShell.Actual <> Self then Exit;
  if R.Ok then
    Por('lblVentasHoy').textContent := Miles(R.Valor) + ' CUP';
end;

function TForm2.IndiceDe(Id: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FProductos) do
    if FProductos[i].Id = Id then
    begin
      Result := i;
      Exit;
    end;
end;

// Cada sección toma uno de los 4 tonos de las fotos sin imagen, según su posición
function TForm2.TonoDe(SeccionId: Integer): Integer;
var
  i: Integer;
begin
  Result := 1;
  for i := 0 to High(FSecciones) do
    if FSecciones[i].Id = SeccionId then
    begin
      Result := (i mod 4) + 1;
      Exit;
    end;
end;

{ ---------- jabas ---------- }

function TForm2.TieneJabas(ProductoId: Integer): Boolean;
var
  j: Integer;
begin
  Result := False;
  for j := 0 to High(FJabas) do
    if FJabas[j].ProductoId = ProductoId then
    begin
      Result := True;
      Exit;
    end;
end;

function TForm2.IndiceJaba(Id: Integer): Integer;
var
  j: Integer;
begin
  Result := -1;
  for j := 0 to High(FJabas) do
    if FJabas[j].Id = Id then
    begin
      Result := j;
      Exit;
    end;
end;

function TForm2.CuentaJabas(ProductoId: Integer; SoloElegidas: Boolean): Integer;
var
  j: Integer;
begin
  Result := 0;
  for j := 0 to High(FJabas) do
    if (FJabas[j].ProductoId = ProductoId) and ((not SoloElegidas) or FJabaSel[j]) then
      Inc(Result);
end;

// La cantidad del producto es la suma de los pesos de las jabas elegidas
procedure TForm2.RecalcularJabas(ProductoId: Integer);
var
  j, k: Integer;
  Suma: Double;
begin
  k := IndiceDe(ProductoId);
  if k < 0 then Exit;
  Suma := 0;
  for j := 0 to High(FJabas) do
    if (FJabas[j].ProductoId = ProductoId) and FJabaSel[j] then
      Suma := Suma + FJabas[j].Peso;
  FQ[k] := Round(Suma * 1000) / 1000;
end;

// ProductoId = 0: todas
procedure TForm2.LimpiarJabas(ProductoId: Integer);
var
  j, k: Integer;
begin
  for j := 0 to High(FJabas) do
    if (ProductoId = 0) or (FJabas[j].ProductoId = ProductoId) then
    begin
      FJabaSel[j] := False;
      k := IndiceDe(FJabas[j].ProductoId);
      if k >= 0 then FQ[k] := 0;
    end;
end;

// Quita (o pone) una jaba concreta: se usa desde la papelera de la venta actual
procedure TForm2.AlternarJaba(Id: Integer);
var
  j: Integer;
begin
  j := IndiceJaba(Id);
  if j < 0 then Exit;
  FJabaSel[j] := not FJabaSel[j];
  RecalcularJabas(FJabas[j].ProductoId);
  Repintar;
end;

// Agrega a la venta la primera jaba libre de ese peso (Clave = peso x 1000)
procedure TForm2.ElegirJaba(ProductoId, Clave: Integer);
var
  j: Integer;
begin
  for j := 0 to High(FJabas) do
    if (FJabas[j].ProductoId = ProductoId) and (not FJabaSel[j])
      and (Round(FJabas[j].Peso * 1000) = Clave) then
    begin
      FJabaSel[j] := True;
      RecalcularJabas(ProductoId);
      Repintar;
      Exit;
    end;
end;

// Chips de la tarjeta: un chip por peso, con cuántas quedan. Se ven 4 y el resto en scroll.
// Cuando ya no queda ninguna de ese peso, el chip desaparece.
procedure TForm2.PonerJabas(Card: TJSElement; ProductoId: Integer);
var
  Ctl: TJSElement;
  Claves, Cuentas: array of Integer;
  j, k, n, Clave, Hallado, Tmp: Integer;
  Html, Texto: string;
begin
  Ctl := Card.querySelector('.db-ctl');
  if Ctl = nil then Exit;

  SetLength(Claves, 0);
  SetLength(Cuentas, 0);
  for j := 0 to High(FJabas) do
  begin
    if (FJabas[j].ProductoId <> ProductoId) or FJabaSel[j] then Continue;
    Clave := Round(FJabas[j].Peso * 1000);
    Hallado := -1;
    for k := 0 to High(Claves) do
      if Claves[k] = Clave then Hallado := k;
    if Hallado < 0 then
    begin
      SetLength(Claves, Length(Claves) + 1);
      SetLength(Cuentas, Length(Cuentas) + 1);
      Hallado := High(Claves);
      Claves[Hallado] := Clave;
      Cuentas[Hallado] := 0;
    end;
    Inc(Cuentas[Hallado]);
  end;

  // de menor a mayor peso
  for n := 0 to High(Claves) - 1 do
    for k := 0 to High(Claves) - 1 - n do
      if Claves[k] > Claves[k + 1] then
      begin
        Tmp := Claves[k];
        Claves[k] := Claves[k + 1];
        Claves[k + 1] := Tmp;
        Tmp := Cuentas[k];
        Cuentas[k] := Cuentas[k + 1];
        Cuentas[k + 1] := Tmp;
      end;

  if Length(Claves) = 0 then
  begin
    Ctl.innerHTML := '<small>Todas las jabas están en la venta</small>';
    Exit;
  end;

  // 2 columnas, alto para 2 filas (4 chips); si hay más, se desliza
  Html := '<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:6px;'
    + 'max-height:84px;overflow-y:auto;align-content:start">';
  for k := 0 to High(Claves) do
  begin
    Texto := Numero(Claves[k] / 1000, 3) + ' lb';
    if Cuentas[k] > 1 then
      Texto := Texto + ' &times;' + IntToStr(Cuentas[k]);
    Html := Html + '<button class="db-chip" type="button" data-prod="' + IntToStr(ProductoId)
      + '" data-jabaw="' + IntToStr(Claves[k]) + '">' + Texto + '</button>';
  end;
  Html := Html + '</div>';
  Ctl.innerHTML := Html;
end;

{ ---------- filtros ---------- }

procedure TForm2.AgregarChip(const Nombre: string; Id: Integer);
var
  Chip: TJSElement;
begin
  Chip := Clonar('tplFiltro');
  Chip.textContent := Nombre;
  Chip.setAttribute('data-seccion', IntToStr(Id));
  divFiltros.ElementHandle.appendChild(Chip);
end;

procedure TForm2.PintarFiltros;
var
  i: Integer;
begin
  divFiltros.ElementHandle.innerHTML := '';
  AgregarChip('Todos', 0);
  for i := 0 to High(FSecciones) do
    AgregarChip(FSecciones[i].Nombre, FSecciones[i].Id);
  MarcarFiltros;
end;

procedure TForm2.MarcarFiltros;
var
  Botones: TJSNodeList;
  i: Integer;
  B: TJSElement;
begin
  Botones := divFiltros.ElementHandle.querySelectorAll('button');
  for i := 0 to Botones.length - 1 do
  begin
    B := TJSElement(Botones.item(i));
    PonerClase(B, 'on', string(B.getAttribute('data-seccion')) = IntToStr(FSeccionId));
  end;
end;

procedure TForm2.FiltrarSeccion(Id: Integer);
begin
  FSeccionId := Id;
  MarcarFiltros;
  PintarProductos;
end;

procedure TForm2.Buscar(const Texto: string);
begin
  FBusqueda := Normalizar(Trim(Texto));
  PintarProductos;
end;

{ ---------- productos ---------- }

procedure TForm2.PintarProductos;
var
  i, N: Integer;
  P: TProducto;
  Card, Ph, Chip: TJSElement;
  Quedan: Double;
  Precio: string;
  ConJabas: Boolean;
begin
  divProductos.ElementHandle.innerHTML := '';
  N := 0;
  for i := 0 to High(FProductos) do
  begin
    P := FProductos[i];
    if not P.Visible then Continue;
    if (FSeccionId <> 0) and (P.SeccionId <> FSeccionId) then Continue;
    if (FBusqueda <> '') and (Pos(FBusqueda, Normalizar(P.Nombre)) = 0) then Continue;

    ConJabas := (P.TipoVenta = 'peso') and TieneJabas(P.Id);

    Card := Clonar('tplProducto');
    Card.setAttribute('data-id', IntToStr(P.Id));
    Ph := Card.querySelector('.db-ph');
    Ph.setAttribute('data-tono', IntToStr(TonoDe(P.SeccionId)));
    PonerFoto(Ph, P.FotoUrl);
    PonerTexto(Card, '.db-un', UnidadDe(P));
    PonerTexto(Card, '.db-nombre', P.Nombre);
    if ConJabas then
      PonerTexto(Card, '.db-detalle', 'Por jaba - elige las que vas a vender')
    else
      PonerTexto(Card, '.db-detalle', DetalleDe(P));

    // El stock es el real de la BD: no baja al armar la venta, solo cuando se completa
    Quedan := Round(P.Stock * 1000) / 1000;
    if Quedan <= 0 then
      PonerTexto(Card, '.db-stock', 'Agotado')
    else if ConJabas then
      PonerTexto(Card, '.db-stock', 'Quedan ' + Numero(Quedan, 3) + ' lb - '
        + IntToStr(CuentaJabas(P.Id, False)) + ' jabas')
    else
      PonerTexto(Card, '.db-stock', 'Quedan ' + Numero(Quedan, 3) + ' ' + UnidadDe(P));
    Chip := Card.querySelector('.db-stock');
    if Chip <> nil then
            PonerClase(Chip, 'db-stock--bajo', TAjustes.StockBajo(Quedan));

    Precio := Miles(P.Precio) + ' CUP';
    if P.TipoVenta = 'peso' then
      Precio := Precio + '/lb';
    PonerTexto(Card, '.db-precio', Precio);

    if ConJabas then
      PonerJabas(Card, P.Id)
    else
      PonerControl(Card, FQ[i], P.Stock > 0);
    divProductos.ElementHandle.appendChild(Card);
    Inc(N);
  end;

  if N = 0 then
    divProductos.ElementHandle.innerHTML :=
      '<div class="db-vacio-grid">No hay productos con ese nombre.</div>';
end;

{ ---------- venta actual ---------- }

procedure TForm2.PintarVenta;
var
  i, j, k, N: Integer;
  Total: Double;
  Lista, Linea, El: TJSElement;
  Filas: TJSNodeList;
  Titulo, Html: string;
begin
  // 1) Conteo (una línea por jaba elegida, una por producto normal), total y estado del panel
  N := 0;
  Total := 0;
  for i := 0 to High(FProductos) do
    if FQ[i] > 0 then
    begin
      if TieneJabas(FProductos[i].Id) then
        N := N + CuentaJabas(FProductos[i].Id, True)
      else
        Inc(N);
      Total := Total + FQ[i] * FProductos[i].Precio;
    end;

  if N = 0 then
    Por('pnlVenta').setAttribute('data-vacia', 'true')
  else
    Por('pnlVenta').setAttribute('data-vacia', 'false');

  Titulo := 'Venta actual';
  if N = 1 then
    Titulo := Titulo + ' - 1 producto'
  else if N > 1 then
    Titulo := Titulo + ' - ' + IntToStr(N) + ' productos';
  Por('lblVentaTitulo').textContent := Titulo;
  Por('lblTotal').textContent := Miles(Total) + ' CUP';

  El := Por('lblVentaAviso');
  if El <> nil then
  begin
    if N > 2 then
      El.textContent := 'Mostrando 2 de ' + IntToStr(N) + ' - desliza para ver mas'
    else
      El.textContent := '';
  end;

  // 2) Lineas de la venta (se arman como texto HTML: no dependen de tplLinea).
  // Se busca el contenedor por su id del HTML, no por el componente divVenta.
  Lista := Por('divVenta');
  if Lista = nil then
  begin
    console.log('No existe el elemento divVenta en el HTML');
    Exit;
  end;
  try
    // guarda el desplazamiento para no saltar al repintar
    asm
      Lista.setAttribute('data-sy', String(Lista.scrollTop));
    end;

    Html := '';
    for i := 0 to High(FProductos) do
    begin
      if FQ[i] <= 0 then Continue;

      if TieneJabas(FProductos[i].Id) then
      begin
        // una línea por jaba, con su propia papelera
        for j := 0 to High(FJabas) do
          if FJabaSel[j] and (FJabas[j].ProductoId = FProductos[i].Id) then
            Html := Html +
              '<div class="db-linea">' +
              '<div class="db-linea-n"><b class="db-nombre">' + Esc(FProductos[i].Nombre)
              + ' - jaba ' + Numero(FJabas[j].Peso, 3) + ' lb</b>' +
              '<small class="db-subtotal">' + Miles(FJabas[j].Peso * FProductos[i].Precio)
              + ' CUP</small></div>' +
              '<div class="db-ctl"></div>' +
              '<button class="db-del" type="button" data-jaba="' + IntToStr(FJabas[j].Id)
              + '" aria-label="Quitar jaba">' +
              '<svg class="db-i"><use href="#ic-trash"/></svg></button></div>';
      end
      else
        Html := Html +
          '<div class="db-linea" data-id="' + IntToStr(FProductos[i].Id) + '">' +
          '<div class="db-linea-n"><b class="db-nombre">' + Esc(FProductos[i].Nombre) + '</b>' +
          '<small class="db-subtotal">' + Miles(FQ[i] * FProductos[i].Precio) + ' CUP</small></div>' +
          '<div class="db-ctl"></div>' +
          '<button class="db-del" type="button" data-accion="quitar" aria-label="Quitar de la venta">' +
          '<svg class="db-i"><use href="#ic-trash"/></svg></button></div>';
    end;
    Lista.innerHTML := Html;

    // el selector de cantidad solo en las líneas normales (las de jaba no lo llevan)
    Filas := Lista.querySelectorAll('.db-linea[data-id]');
    for k := 0 to Filas.length - 1 do
    begin
      Linea := TJSElement(Filas.item(k));
      if Linea = nil then Continue;
      i := IndiceDe(StrToIntDef(string(Linea.getAttribute('data-id')), 0));
      if i >= 0 then
        PonerControl(Linea, FQ[i], True);
    end;

    asm
      Lista.scrollTop = Number(Lista.getAttribute('data-sy') || 0);
    end;
  except
    if El <> nil then
      El.textContent := 'Error al mostrar las lineas (revisa la consola F12)';
  end;

  // 3) En telefono el panel va fijo arriba de la barra inferior: se deja espacio
  // al final de la lista para que no tape los ultimos productos. En PC no hace falta.
  asm
    var d = document.getElementById('pnlVenta');
    var m = document.querySelector('.db-main');
    if (d && m) {
      var fijo = getComputedStyle(d).position === 'fixed' && d.offsetHeight > 0;
      m.style.paddingBottom = fijo
        ? ((parseFloat(getComputedStyle(d).bottom) || 0) + d.offsetHeight + 16) + 'px'
        : '';
    }
  end;
end;

procedure TForm2.Repintar;
begin
  PintarProductos;
  PintarVenta;
end;

{ ---------- cantidades ---------- }

procedure TForm2.Accionar(Id: Integer; const Accion: string);
var
  i: Integer;
  V: Double;
begin
  i := IndiceDe(Id);
  if i < 0 then Exit;

  // productos con jabas: lo único que se hace aquí es quitarlos de la venta
  if TieneJabas(Id) then
  begin
    if Accion = 'quitar' then
    begin
      LimpiarJabas(Id);
      Repintar;
    end;
    Exit;
  end;

  if Accion = 'mas' then
  begin
    V := R2(FQ[i] + Paso(FProductos[i]));
    if V > FProductos[i].Stock then V := FProductos[i].Stock;
    FQ[i] := V;
  end
  else if Accion = 'menos' then
  begin
    V := R2(FQ[i] - Paso(FProductos[i]));
    if V < 0 then V := 0;
    FQ[i] := V;
  end
  else if Accion = 'quitar' then
    FQ[i] := 0
  else
    Exit;                                  // 'cantidad' se atiende al cambiar el texto
  Repintar;
end;

procedure TForm2.FijarCantidad(Id: Integer; Valor: Double);
var
  i: Integer;
begin
  i := IndiceDe(Id);
  if i < 0 then Exit;
  if TieneJabas(Id) then Exit;             // con jabas la cantidad sale de las jabas elegidas

  if Valor <= 0 then
    Valor := 0
  else
  begin
    if FProductos[i].TipoVenta = 'peso' then
      Valor := R2(Valor)
    else
    begin
      Valor := Round(Valor);
      if Valor < 1 then Valor := 1;
    end;
    if Valor > FProductos[i].Stock then Valor := FProductos[i].Stock;
  end;
  FQ[i] := Valor;
  Repintar;
end;

procedure TForm2.btnVaciarClick(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to High(FQ) do
    FQ[i] := 0;
  LimpiarJabas(0);
  Repintar;
end;

// Guarda la venta armada en sessionStorage ('venta') y va a la pantalla #/cobrar
// Con jabas: una línea por cada jaba elegida (cantidad = peso, jaba_id = la jaba)
procedure TForm2.btnCobrarClick(Sender: TObject);
var
  Items: TJSArray;
  Item, Venta: TJSObject;
  i, j: Integer;
  Total: Double;
begin
  Items := TJSArray.new;
  Total := 0;
  for i := 0 to High(FProductos) do
  begin
    if FQ[i] <= 0 then Continue;

    if TieneJabas(FProductos[i].Id) then
    begin
      for j := 0 to High(FJabas) do
        if FJabaSel[j] and (FJabas[j].ProductoId = FProductos[i].Id) then
        begin
          Item := TJSObject.new;
          Item['id'] := FProductos[i].Id;
          Item['nombre'] := FProductos[i].Nombre + ' (jaba ' + Numero(FJabas[j].Peso, 3) + ' lb)';
          Item['unidad'] := 'lb';
          Item['cantidad'] := FJabas[j].Peso;
          Item['precio'] := FProductos[i].Precio;
          Item['jaba_id'] := FJabas[j].Id;
          Items.push(Item);
          Total := Total + FJabas[j].Peso * FProductos[i].Precio;
        end;
      Continue;
    end;

    Item := TJSObject.new;
    Item['id'] := FProductos[i].Id;
    Item['nombre'] := FProductos[i].Nombre;
    Item['unidad'] := UnidadDe(FProductos[i]);
    Item['cantidad'] := FQ[i];
    Item['precio'] := FProductos[i].Precio;
    Items.push(Item);
    Total := Total + FQ[i] * FProductos[i].Precio;
  end;
  if Items.length = 0 then Exit;

  Venta := TJSObject.new;
  Venta['items'] := Items;
  Venta['total'] := Total;
  window.sessionStorage.setItem('venta', TJSJSON.stringify(Venta));
  TNavegacion.IrARuta('cobrar');
end;

end.
