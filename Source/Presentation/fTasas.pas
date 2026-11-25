unit fTasas;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs;

type
  TForm7 = class(TWebForm)
    procedure WebFormCreate(Sender: TObject);
  end;

var
  Form7: TForm7;

implementation

{$R *.dfm}

uses
  uShell, uNavegacion, uTasas, uAjustes;

var
  GUsd, GEur, GMlc: Double;     // las tasas que usa el conversor (las de Ajustes si las fijaste)

function El(const Id: string): TJSElement;
begin
  Result := document.getElementById(Id);
end;

function Fmt(N: Double; Dec: Integer): string;
begin
  asm
    Result = N.toLocaleString('en-US', {maximumFractionDigits: Dec}).replace(/,/g, ' ');
  end;
end;

function Fmt2(N: Double): string;
begin
  asm
    Result = N.toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2}).replace(/,/g, ' ');
  end;
end;

function LeerMonto: Double;
begin
  asm
    Result = parseFloat(document.getElementById('tsMonto').value) || 0;
  end;
end;

function LeerMoneda: string;
begin
  asm
    var s = document.querySelector('#tsChips .sel');
    Result = s ? s.getAttribute('data-mon') : 'usd';
  end;
end;

procedure Calcular;
var
  R: Double;
  Mon: string;
begin
  Mon := LeerMoneda;
  if Mon = 'eur' then R := GEur
  else if Mon = 'mlc' then R := GMlc
  else R := GUsd;
  El('tsRes').innerHTML := Fmt2(LeerMonto * R) + ' CUP';
end;

procedure MostrarToast(const Msg: string);
begin
  El('tsToastTxt').innerHTML := Msg;
  El('tsToast').removeAttribute('hidden');
  window.setTimeout(
    procedure
    begin
      if El('tsToast') <> nil then
        El('tsToast').setAttribute('hidden', '');
    end, 2200);
end;

// Variación en CUP respecto a hace ~24 h: +5 sube, -3 baja, 0 igual
procedure PonerTendencia(const Id: string; Cambio: Double; Mostrar: Boolean);
var
  E: TJSElement;
begin
  E := El(Id);
  if not Mostrar then
  begin
    E.setAttribute('hidden', '');
    Exit;
  end;
  E.removeAttribute('hidden');
  if Cambio > 0.0049 then
  begin
    E.className := 'ts-trend up';
    E.innerHTML := '+' + Fmt(Cambio, 2);
  end
  else if Cambio < -0.0049 then
  begin
    E.className := 'ts-trend dn';
    E.innerHTML := Fmt(Cambio, 2);
  end
  else
  begin
    E.className := 'ts-trend eq';
    E.innerHTML := '0';
  end;
end;

// "Tú la tomas en X CUP" cuando la moneda está fijada a mano en Ajustes
procedure PonerNota(const Id: string; Manual: Boolean; Valor: Double);
var
  E: TJSElement;
begin
  E := El(Id);
  if Manual then
  begin
    E.innerHTML := 'Tú la tomas en <b>' + Fmt(Valor, 2) + ' CUP</b> · configurado en Ajustes';
    E.removeAttribute('hidden');
  end
  else
    E.setAttribute('hidden', '');
end;

procedure Pintar(T: TTasasCup);
begin
  GUsd := T.EfUsd;
  GEur := T.EfEur;
  GMlc := T.EfMlc;

  // las tarjetas muestran siempre la tasa de elToque
  El('tsUsd').innerHTML := Fmt(T.Usd, 2) + '<small>CUP</small>';
  El('tsEur').innerHTML := Fmt(T.Eur, 2) + '<small>CUP</small>';
  El('tsMlc').innerHTML := Fmt(T.Mlc, 2) + '<small>CUP</small>';

  PonerTendencia('tsTUsd', T.CamUsd, T.HayCambio);
  PonerTendencia('tsTEur', T.CamEur, T.HayCambio);
  PonerTendencia('tsTMlc', T.CamMlc, T.HayCambio);

  PonerNota('tsNotaUsd', T.ManUsd, T.EfUsd);
  PonerNota('tsNotaEur', T.ManEur, T.EfEur);
  PonerNota('tsNotaMlc', T.ManMlc, T.EfMlc);

  if T.Origen = 'toque' then
    El('tsFuente').innerHTML := 'Fuente: elToque · en línea'
  else if T.Origen = 'guardada' then
    El('tsFuente').innerHTML := 'Sin conexión · última tasa guardada'
  else
    El('tsFuente').innerHTML := 'Tasa de ejemplo · aún sin consultar';

  if T.Hora <> '' then
    El('tsHora').innerHTML := 'Actualizado · ' + T.Hora
  else
    El('tsHora').innerHTML := 'Sin tasa real todavía';

  Calcular;
end;

[async]
procedure Actualizar(Manual: Boolean);
var
  T: TTasasCup;
begin
  if El('tsBtn') = nil then Exit;
  El('tsBtn').setAttribute('disabled', '');
  T := await(TTasasCup, TTasas.Consultar);
  if El('tsBtn') = nil then Exit;      // se salió de la pantalla mientras esperaba
  El('tsBtn').removeAttribute('disabled');
  Pintar(T);
  if Manual then
  begin
    if T.Origen = 'toque' then
      MostrarToast('Tasas actualizadas desde elToque')
    else
      MostrarToast('Sin conexión · se usa la última tasa guardada');
  end;
end;

// Marca en el conversor la moneda predeterminada de Ajustes
procedure ElegirBase;
var
  Base: string;
begin
  Base := TAjustes.MonedaBase;
  asm
    document.querySelectorAll('#tsChips .ts-chip').forEach(function (c) {
      c.classList.toggle('sel', c.getAttribute('data-mon') === Base);
    });
  end;
end;

function AlClicActualizar(Event: TJSEvent): Boolean;
begin
  Result := True;
  Actualizar(True);
end;

function AlCalcular(Event: TJSEvent): Boolean;
begin
  Result := True;
  Calcular;
end;

function AlClicChip(Event: TJSEvent): Boolean;
begin
  Result := True;
  asm
    var b = Event.target.closest('.ts-chip');
    if (b) {
      document.querySelectorAll('#tsChips .ts-chip').forEach(function (x) { x.classList.remove('sel'); });
      b.classList.add('sel');
    }
  end;
  Calcular;
end;

function AlClicAtras(Event: TJSEvent): Boolean;
begin
  Result := True;
  if window.history.length > 1 then
    window.history.back
  else
    window.location.hash := '/vender';   // abierto directo por URL: no hay a dónde volver
end;

procedure TForm7.WebFormCreate(Sender: TObject);
begin
  TNavegacion.Registrar(Self);
  TShell.Activar('mas');                 // marca "Más" en el menú inferior

  El('tsBtn').addEventListener('click', @AlClicActualizar);
  El('tsMonto').addEventListener('input', @AlCalcular);
  El('tsChips').addEventListener('click', @AlClicChip);
  El('tsAtras').addEventListener('click', @AlClicAtras);

  ElegirBase;
  Pintar(TTasas.Guardada);               // sale al instante con lo guardado (sirve offline)
  Actualizar(False);                     // y consulta en segundo plano
end;

end.
