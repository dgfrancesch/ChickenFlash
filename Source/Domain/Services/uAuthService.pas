unit uAuthService;

interface

uses
  System.SysUtils, JS, Web;

type
  TAuthResult = class
  public
    Ok: Boolean;
    Mensaje: string;
  end;

  TAuthService = class
  public
    [async]
    class function Login(const Usuario, Clave: string): TAuthResult;
    class procedure Logout;
    class function HaySesion: Boolean;
  end;

implementation

uses
  WEBLib.JSON, uConfig, uHttp, uSession;

 [async]
class function TAuthService.Login(const Usuario, Clave: string): TAuthResult;
var
  J: TJSONObject;
  R: TApiResponse;
begin
  Result := TAuthResult.Create;

  if (Trim(Usuario) = '') or (Clave = '') then
    Result.Mensaje := 'Escribe tu usuario y contraseña'
  else
  begin
    J := TJSONObject.Create;
    try
      J.AddPair('email', LowerCase(Trim(Usuario)) + DOMINIO);
      J.AddPair('password', Clave);
      R := await(TApiResponse, THttp.Send('POST',
        '/auth/v1/token?grant_type=password', J.ToString, ''));
    finally
      J.Free;
    end;

    if R.Ok then
    begin
      TSession.Save(R.Body);
      Result.Ok := True;
    end
    else if R.Status = 400 then
      Result.Mensaje := 'Usuario o contraseña incorrectos'
    else if R.Status = 429 then
      Result.Mensaje := 'Demasiados intentos. Espera un momento.'
    else
      Result.Mensaje := 'No se pudo conectar. Revisa el internet.';
  end;
end;

class procedure TAuthService.Logout;
begin
  TSession.Clear;
end;

class function TAuthService.HaySesion: Boolean;
begin
  Result := TSession.IsValid;
end;

end.
