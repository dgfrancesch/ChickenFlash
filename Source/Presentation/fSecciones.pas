unit fSecciones;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, uInventarioService, WEBLib.WebCtrls,
  Vcl.StdCtrls, WEBLib.StdCtrls, Vcl.Controls;

type
  TForm5 = class(TWebForm)
    secNuevoActiva: TWebButton;
    secPantalla: TWebHTMLDiv;
    secVolver: TWebButton;
    secNuevoNombre: TWebEdit;
    secRed: TWebHTMLSpan;
    secToastTxt: TWebHTMLSpan;
    secBtnAgregar: TWebButton;
    secLista: TWebHTMLDiv;
    secToast: TWebHTMLDiv;
    procedure WebFormCreate(Sender: TObject);
    procedure secVolverClick(Sender: TObject);
    procedure secBtnAgregarClick(Sender: TObject);
    procedure secNuevoActivaClick(Sender: TObject);
    procedure secNuevoNombreKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FSecciones: array of TSeccion;
    FConfirmarId: Integer;     // sección que espera confirmar el borrado (0 = ninguna)
    FNuevaActiva: Boolean;
    FMoviendo: Boolean;
    FCreando: Boolean;
    [async]
    procedure Cargar;
    [async]
    procedure Crear;
    [async]
    procedure Renombrar(Id: Integer; const Nombre: string);
    [async]
    procedure CambiarActiva(Id: Integer);
    [async]
    procedure Mover(Id, Dir: Integer);
    [async]
    procedure Borrar(Id: Integer);
    procedure AlternarNueva;
    procedure Pintar;
    procedure Aviso(const Msg: string);
    function Buscar(Id: Integer): Integer;
    function NombreRepetido(const Nombre: string; ExceptoId: Integer): Boolean;
  public
  end;

var
  Form5: TForm5;

implementation

uses
  uShell, uNavegacion, uDom;

{$R *.dfm}

{ ---------- eventos de las tarjetas (se crean por código) ---------- }

function AlClicSec(Event: TJSEvent): Boolean;
var
  B: TJSElement;
  A: string;
  Id: Integer;
  P: TForm5;
begin
  Result := True;
  if not (TShell.Actual is TForm5) then Exit;
  P := TForm5(TShell.Actual);

  B := Ancestro(TJSElement(Event.target), '[data-a]');
  if B = nil then Exit;
  A := string(B.getAttribute('data-a'));
  Id := StrToIntDef(string(B.getAttribute('data-id')), 0);

  if A = 'act' then
    P.CambiarActiva(Id)
  else if A = 'up' then
    P.Mover(Id, -1)
  else if A = 'down' then
    P.Mover(Id, 1)
  else if A = 'del' then
    P.Borrar(Id);
end;

// El nombre se guarda al salir del campo o con Enter
function AlCambiarSec(Event: TJSEvent): Boolean;
var
  Inp: TJSElement;
begin
  Result := True;
  if not (TShell.Actual is TForm5) then Exit;
  Inp := Ancestro(TJSElement(Event.target), 'input[data-a="rename"]');
  if Inp = nil then Exit;
  TForm5(TShell.Actual).Renombrar(
    StrToIntDef(string(Inp.getAttribute('data-id')), 0),
    Trim(string(TJSHTMLInputElement(Inp).value)));
end;

// Enter en el nombre de una tarjeta = guardar (dispara el change)
function AlTeclaSec(Event: TJSEvent): Boolean;
var
  T: TJSElement;
begin
  Result := True;
  if string(TJSKeyBoardEvent(Event).key) <> 'Enter' then Exit;
  T := TJSElement(Event.target);
  if string(T.getAttribute('data-a')) = 'rename' then
  begin
    asm
      T.blur();
    end;
  end;
end;

{ ---------- pantalla ---------- }

procedure TForm5.WebFormCreate(Sender: TObject);
begin
  TShell.Activar('inventario');   // la barra inferior sigue marcando Inventario
  TShell.Actual := Self;
  FNuevaActiva := True;
  FConfirmarId := 0;

  secVolver.OnClick := secVolverClick;
  secBtnAgregar.OnClick := secBtnAgregarClick;
  secNuevoActiva.OnClick := secNuevoActivaClick;
  secNuevoNombre.OnKeyDown := secNuevoNombreKeyDown;

  // la lista se pinta por código, así que sus clics van por un solo listener
  secLista.ElementHandle.addEventListener('click', @AlClicSec);
  secLista.ElementHandle.addEventListener('change', @AlCambiarSec);
  secLista.ElementHandle.addEventListener('keydown', @AlTeclaSec);
  Cargar;
end;

procedure TForm5.secVolverClick(Sender: TObject);
begin
  TNavegacion.IrARuta('inventario');
end;

procedure TForm5.secBtnAgregarClick(Sender: TObject);
begin
  Crear;
end;

procedure TForm5.secNuevoActivaClick(Sender: TObject);
begin
  AlternarNueva;
end;

procedure TForm5.secNuevoNombreKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 13 then
    Crear;
end;

procedure TForm5.Cargar;
var
  RS: TResultadoSecciones;
  RP: TResultadoProductos;
  i, j: Integer;
begin
  if Length(FSecciones) = 0 then
    secLista.ElementHandle.innerHTML := '<div class="empty">Cargando secciones...</div>';

  RS := await(TResultadoSecciones, TInventarioService.CargarSeccionesTodas);
  if TShell.Actual <> Self then Exit;
  if not RS.Ok then
  begin
    secLista.ElementHandle.innerHTML := '<div class="empty">' + Esc(RS.Error) + '</div>';
    Exit;
  end;

  RP := await(TResultadoProductos, TInventarioService.CargarProductos);
  if TShell.Actual <> Self then Exit;
  if RP.Ok then
    for i := 0 to High(RS.Items) do
      for j := 0 to High(RP.Items) do
        if RP.Items[j].SeccionId = RS.Items[i].Id then
          Inc(RS.Items[i].Productos);

  FSecciones := RS.Items;
  Pintar;
end;

procedure TForm5.Pintar;
var
  Html, Id, Clase, Estado, Sw, Chk, DisUp, DisDown, Conf, Cant: string;
  i: Integer;
  S: TSeccion;
begin
  if Length(FSecciones) = 0 then
  begin
    secLista.ElementHandle.innerHTML :=
      '<div class="empty">Aún no hay secciones. Agrega la primera arriba.</div>';
    Exit;
  end;

  Html := '';
  for i := 0 to High(FSecciones) do
  begin
    S := FSecciones[i];
    Id := IntToStr(S.Id);

    if S.Activa then
    begin
      Clase := 'sec-card';
      Estado := '<span class="badge">Activa</span>';
      Sw := 'sw on';
      Chk := 'true';
    end
    else
    begin
      Clase := 'sec-card is-off';
      Estado := '<span class="badge off">Inactiva</span>';
      Sw := 'sw';
      Chk := 'false';
    end;

    if i = 0 then DisUp := ' disabled' else DisUp := '';
    if i = High(FSecciones) then DisDown := ' disabled' else DisDown := '';
    if FConfirmarId = S.Id then Conf := '¿Borrar?' else Conf := '';
    if S.Productos = 1 then Cant := '1 producto' else Cant := IntToStr(S.Productos) + ' productos';

    Html := Html +
      '<article class="' + Clase + '">' +
        '<div class="sec-title">' +
          '<span class="order-badge">#' + IntToStr(i + 1) + '</span>' +
          '<input class="sec-name-inp" type="text" value="' + Esc(S.Nombre) + '" data-a="rename" data-id="' + Id + '" aria-label="Nombre de sección">' +
        '</div>' +
        '<div class="sec-meta"><span>' + Cant + '</span>' + Estado + '</div>' +
        '<div class="sec-actions">' +
          '<div class="vis-ctl"><span>Activa</span>' +
            '<button class="' + Sw + '" type="button" data-a="act" data-id="' + Id + '" role="switch" aria-checked="' + Chk + '"></button>' +
          '</div>' +
          '<div class="btns">' +
            '<button class="ord-btn" type="button" data-a="up" data-id="' + Id + '" aria-label="Subir"' + DisUp + '><svg class="i"><use href="#i-up"></use></svg></button>' +
            '<button class="ord-btn" type="button" data-a="down" data-id="' + Id + '" aria-label="Bajar"' + DisDown + '><svg class="i"><use href="#i-down"></use></svg></button>' +
            '<button class="del-btn" type="button" data-a="del" data-id="' + Id + '" aria-label="Eliminar sección"><svg class="i"><use href="#i-trash"></use></svg>' + Conf + '</button>' +
          '</div>' +
        '</div>' +
      '</article>';
  end;
  secLista.ElementHandle.innerHTML := Html;
end;

function TForm5.Buscar(Id: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to High(FSecciones) do
    if FSecciones[i].Id = Id then
    begin
      Result := i;
      Exit;
    end;
end;

function TForm5.NombreRepetido(const Nombre: string; ExceptoId: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FSecciones) do
    if (FSecciones[i].Id <> ExceptoId) and
       (LowerCase(FSecciones[i].Nombre) = LowerCase(Nombre)) then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TForm5.Aviso(const Msg: string);
var
  El: TJSElement;
begin
  secToastTxt.ElementHandle.textContent := Msg;
  El := secToast.ElementHandle;
  El.removeAttribute('hidden');
  asm
    clearTimeout(window.__secToast);
    window.__secToast = setTimeout(function(){ El.setAttribute('hidden', ''); }, 2200);
  end;
end;

procedure TForm5.AlternarNueva;
begin
  FNuevaActiva := not FNuevaActiva;
  PonerClase(secNuevoActiva.ElementHandle, 'on', FNuevaActiva);
  if FNuevaActiva then
    secNuevoActiva.ElementHandle.setAttribute('aria-checked', 'true')
  else
    secNuevoActiva.ElementHandle.setAttribute('aria-checked', 'false');
end;

{ ---------- acciones ---------- }

procedure TForm5.Crear;
var
  Nombre: string;
  Orden, i: Integer;
  R: TResultado;
begin
  if FCreando then Exit;
  Nombre := Trim(secNuevoNombre.Text);
  if Nombre = '' then
  begin
    Aviso('Escribe el nombre de la sección.');
    Exit;
  end;
  if NombreRepetido(Nombre, 0) then
  begin
    Aviso('Ya existe una sección con ese nombre.');
    Exit;
  end;

  Orden := 1;
  for i := 0 to High(FSecciones) do
    if FSecciones[i].Orden >= Orden then
      Orden := FSecciones[i].Orden + 1;

  FCreando := True;
  R := await(TResultado, TInventarioService.CrearSeccion(Nombre, Orden, FNuevaActiva));
  FCreando := False;
  if not R.Ok then
  begin
    Aviso(R.Error);
    Exit;
  end;
  secNuevoNombre.Text := '';
  Aviso('Sección agregada');
  Cargar;
end;

procedure TForm5.Renombrar(Id: Integer; const Nombre: string);
var
  Idx: Integer;
  S: TSeccion;
  R: TResultado;
begin
  Idx := Buscar(Id);
  if Idx < 0 then Exit;
  S := FSecciones[Idx];
  if Nombre = S.Nombre then Exit;
  if Nombre = '' then
  begin
    Pintar;                       // vuelve al nombre anterior
    Exit;
  end;
  if NombreRepetido(Nombre, Id) then
  begin
    Pintar;
    Aviso('Ya existe una sección con ese nombre.');
    Exit;
  end;

  R := await(TResultado, TInventarioService.ActualizarSeccion(Id, 'nombre', Nombre));
  if not R.Ok then
  begin
    Pintar;
    Aviso(R.Error);
    Exit;
  end;
  S.Nombre := Nombre;
  Aviso('Cambio guardado');
end;

procedure TForm5.CambiarActiva(Id: Integer);
var
  Idx: Integer;
  S: TSeccion;
  R: TResultado;
begin
  FConfirmarId := 0;
  Idx := Buscar(Id);
  if Idx < 0 then Exit;
  S := FSecciones[Idx];
  S.Activa := not S.Activa;
  Pintar;

  R := await(TResultado, TInventarioService.ActualizarSeccion(Id, 'activa', S.Activa));
  if not R.Ok then
  begin
    S.Activa := not S.Activa;     // si falla, vuelve al estado anterior
    Pintar;
    Aviso(R.Error);
    Exit;
  end;
  if S.Activa then
    Aviso('Sección activa')
  else
    Aviso('Sección inactiva');
end;

// Sube (Dir = -1) o baja (Dir = 1). Renumera 1..N y guarda solo lo que cambió.
procedure TForm5.Mover(Id, Dir: Integer);
var
  Idx, Otro, i: Integer;
  Tmp: TSeccion;
  R: TResultado;
begin
  if FMoviendo then Exit;
  FConfirmarId := 0;
  Idx := Buscar(Id);
  Otro := Idx + Dir;
  if (Idx < 0) or (Otro < 0) or (Otro > High(FSecciones)) then Exit;

  Tmp := FSecciones[Idx];
  FSecciones[Idx] := FSecciones[Otro];
  FSecciones[Otro] := Tmp;
  Pintar;

  FMoviendo := True;
  for i := 0 to High(FSecciones) do
    if FSecciones[i].Orden <> i + 1 then
    begin
      R := await(TResultado, TInventarioService.ActualizarSeccion(FSecciones[i].Id, 'orden', i + 1));
      if not R.Ok then
      begin
        FMoviendo := False;
        Aviso(R.Error);
        Cargar;                   // recarga el orden real de la BD
        Exit;
      end;
      FSecciones[i].Orden := i + 1;
    end;
  FMoviendo := False;
  Aviso('Orden actualizado');
end;

// Primer toque pide confirmar (el botón dice "¿Borrar?"), el segundo borra.
procedure TForm5.Borrar(Id: Integer);
var
  Idx, N: Integer;
  R: TResultado;
begin
  Idx := Buscar(Id);
  if Idx < 0 then Exit;
  if FConfirmarId <> Id then
  begin
    FConfirmarId := Id;
    Pintar;
    Exit;
  end;
  FConfirmarId := 0;

  // Se consulta la BD (incluye productos ocultos) para no dejar productos huérfanos
  N := await(Integer, TInventarioService.ContarProductos(Id));
  if N <> 0 then
  begin
    Pintar;
    if N > 0 then
      Aviso('Tiene productos. Muévelos a otra sección o desactívala.')
    else
      Aviso('No se pudo comprobar los productos. Intenta de nuevo.');
    Exit;
  end;

  R := await(TResultado, TInventarioService.EliminarSeccion(Id));
  if not R.Ok then
  begin
    Pintar;
    Aviso(R.Error);
    Exit;
  end;
  Idx := Buscar(Id);
  if Idx >= 0 then
    Delete(FSecciones, Idx, 1);
  Pintar;
  Aviso('Sección eliminada');
end;

end.
