unit uTasas;

// Tasas de cambio de elToque, vía la función de Supabase (super-task).
// - Consultar: pregunta ahora; si funciona la guarda, si no devuelve la última guardada.
// - Guardada: la última tasa que se pudo bajar (o una de ejemplo si nunca hubo).

interface

uses
  System.SysUtils, JS, Web;

type
  TTasasCup = class
  public
    Usd: Double;        // CUP por 1 USD
    Eur: Double;        // CUP por 1 EUR
    Mlc: Double;        // CUP por 1 MLC
    Hora: string;       // hora local en que se bajó esta tasa
    Origen: string;     // 'toque' (recién consultada), 'guardada' o 'ejemplo'
  end;

  TTasas = class
  public
    class function Guardada: TTasasCup;
    [async]
    class function Consultar: TTasasCup;
  end;

implementation

uses
  uConfig;

const
  FUNCION_TASAS = '/functions/v1/super-task';
  MS_CONSULTA = 15000;
  // Último recurso, solo si nunca se pudo bajar una tasa real
  EJ_USD = 400;
  EJ_EUR = 430;
  EJ_MLC = 280;

// No usa el prefijo "cf:" a propósito: al cerrar sesión no se borra
function LeerGuardada: TJSObject;
begin
  asm
    try { Result = window.JSON.parse(localStorage.getItem('cftasas') || 'null'); } catch (e) { Result = null; }
  end;
end;

procedure GuardarTasas(const Dato: TJSObject);
begin
  asm
    try { localStorage.setItem('cftasas', window.JSON.stringify(Dato)); } catch (e) {}
  end;
end;

function HoraLocal(Ms: Double): string;
begin
  asm
    Result = Ms ? new Date(Ms).toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'}) : '';
  end;
end;

// Nunca falla: devuelve {status, body}. Sin red o tiempo agotado => status 0.
function TasasFetch(const Url, ApiKey: string; Ms: Integer): TJSPromise;
begin
  asm
    var ctrl = new AbortController();
    var timer = setTimeout(function () { ctrl.abort(); }, Ms);
    Result = fetch(Url, {
      headers: { 'apikey': ApiKey, 'Accept': 'application/json' },
      signal: ctrl.signal,
      cache: 'no-store'
    }).then(function (r) {
      return r.text().then(function (t) { clearTimeout(timer); return { status: r.status, body: t }; });
    }).catch(function () { clearTimeout(timer); return { status: 0, body: '' }; });
  end;
end;

// Saca USD, EUR y MLC del JSON. El euro en elToque viene como ECU. null si algo no cuadra.
function LeerTasas(const Cuerpo: string): TJSObject;
begin
  asm
    try {
      var d = window.JSON.parse(Cuerpo);
      var t = d.tasas || {};
      var usd = Number(t.USD);
      var eur = Number(t.EUR != null ? t.EUR : t.ECU);
      var mlc = Number(t.MLC);
      if (usd > 0 && eur > 0 && mlc > 0) {
        Result = { USD: usd, EUR: eur, MLC: mlc, ts: Date.now() };
      } else {
        Result = null;
      }
    } catch (e) { Result = null; }
  end;
end;

function ADe(O: TJSObject; const Origen: string): TTasasCup;
begin
  Result := TTasasCup.Create;
  Result.Usd := Double(O['USD']);
  Result.Eur := Double(O['EUR']);
  Result.Mlc := Double(O['MLC']);
  Result.Hora := HoraLocal(Double(O['ts']));
  Result.Origen := Origen;
end;

class function TTasas.Guardada: TTasasCup;
var
  O: TJSObject;
begin
  O := LeerGuardada;
  if O <> nil then
    Result := ADe(O, 'guardada')
  else
  begin
    Result := TTasasCup.Create;
    Result.Usd := EJ_USD;
    Result.Eur := EJ_EUR;
    Result.Mlc := EJ_MLC;
    Result.Hora := '';
    Result.Origen := 'ejemplo';
  end;
end;

class function TTasas.Consultar: TTasasCup;
var
  Res, Dato: TJSObject;
  Estado: Integer;
begin
  Res := await(TJSObject, TasasFetch(SB_URL + FUNCION_TASAS, SB_KEY, MS_CONSULTA));
  Estado := Integer(Res['status']);
  if (Estado >= 200) and (Estado < 300) then
  begin
    Dato := LeerTasas(string(Res['body']));
    if Dato <> nil then
    begin
      GuardarTasas(Dato);
      Result := ADe(Dato, 'toque');
      Exit;
    end;
    console.log('uTasas: la respuesta no trae tasas válidas: ' + string(Res['body']));
  end
  else
    console.log('uTasas: no se pudo consultar elToque (' + IntToStr(Estado) + ')');
  Result := Guardada;
end;

end.
