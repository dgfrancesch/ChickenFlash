unit uHttp;

interface

uses
  System.SysUtils, JS, Web, WEBLib.REST;

type
  TApiResponse = class
  public
    Ok: Boolean;
    Status: Integer;
    Body: string;
    DeCache: Boolean;       // True = sin conexión: son los datos de la última copia guardada
    CacheHora: string;      // hora de esa copia
  end;

  THttp = class
  public
    [async]
    class function Send(const Method, Path, Body, Token: string): TApiResponse;
    class procedure LimpiarCache;
  end;

implementation

uses
  uConfig;

{ ---------- copia local de las lecturas (GET) ---------- }

procedure GuardarCache(const Clave, Cuerpo: string);
begin
  asm
    try {
      localStorage.setItem('cf:' + Clave, Cuerpo);
      localStorage.setItem('cf:t:' + Clave, String(Date.now()));
    } catch (e) {}
  end;
end;

function LeerCache(const Clave: string): string;
begin
  asm
    try { Result = localStorage.getItem('cf:' + Clave) || ''; } catch (e) { Result = ''; }
  end;
end;

function HoraCache(const Clave: string): string;
begin
  asm
    var t = Number(localStorage.getItem('cf:t:' + Clave));
    Result = t ? new Date(t).toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'}) : '';
  end;
end;

// Marca el body con "sin-red": muestra u oculta el aviso de la barra superior
procedure PonerSinRed(Si: Boolean);
begin
  asm
    document.body.classList.toggle('sin-red', Si);
  end;
end;

class procedure THttp.LimpiarCache;
begin
  asm
    Object.keys(localStorage)
      .filter(function (k) { return k.indexOf('cf:') === 0; })
      .forEach(function (k) { localStorage.removeItem(k); });
  end;
end;

{ ---------- petición ---------- }

class function THttp.Send(const Method, Path, Body, Token: string): TApiResponse;
var
  Req: TWebHttpRequest;
  Xhr: TJSXMLHttpRequest;
  Copia: string;
begin
  Result := TApiResponse.Create;
  Req := TWebHttpRequest.Create(nil);
  try
    Req.Headers.Clear;
    Req.Headers.AddPair('apikey', SB_KEY);
    Req.Headers.AddPair('Content-Type', 'application/json');
    if Token <> '' then
      Req.Headers.AddPair('Authorization', 'Bearer ' + Token);
    if (Method = 'PATCH') or (Method = 'DELETE') then
      Req.Headers.AddPair('Prefer', 'return=representation');

    if Method = 'POST' then
    begin
      Req.Command := httpPOST;
      Req.PostData := Body;
    end
    else if Method = 'PATCH' then
    begin
      Req.Command := httpPATCH;
      Req.PostData := Body;
    end
    else if Method = 'DELETE' then
      Req.Command := httpDELETE
    else
      Req.Command := httpGET;

    Req.URL := SB_URL + Path;
    try
      Xhr := await(TJSXMLHttpRequest, Req.Perform);
      Result.Status := Xhr.status;
      Result.Body := string(Xhr.responseText);
      Result.Ok := (Xhr.status >= 200) and (Xhr.status < 300);
    except
      Result.Status := 0;
      Result.Ok := False;
    end;
  finally
    Req.Free;
  end;

  PonerSinRed(Result.Status = 0);

  if Method = 'GET' then
  begin
    if Result.Ok then
      GuardarCache(Path, Result.Body)                 // lectura buena: se guarda la copia
    else if Result.Status = 0 then
    begin
      Copia := LeerCache(Path);                       // sin conexión: se usa la última copia
      if Copia <> '' then
      begin
        Result.Body := Copia;
        Result.Status := 200;
        Result.Ok := True;
        Result.DeCache := True;
        Result.CacheHora := HoraCache(Path);
      end;
    end;
  end;
end;

end.
