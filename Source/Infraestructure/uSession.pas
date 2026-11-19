unit uSession;

interface

type
  TSession = class
  public
    class procedure Save(const SessionJson: string);
    class procedure Clear;
    class function Token: string;
    class function UserId: string;
    class function IsValid: Boolean;
  end;

implementation

uses
  JS, Web, uConfig;

function LeerSesion: TJSObject;
begin
  Result := nil;
  try
    Result := TJSObject(TJSJSON.parse(window.localStorage.getItem(SESSION_KEY)));
  except
    Result := nil;
  end;
end;

class procedure TSession.Save(const SessionJson: string);
begin
  window.localStorage.setItem(SESSION_KEY, SessionJson);
end;

class procedure TSession.Clear;
begin
  window.localStorage.removeItem(SESSION_KEY);
end;

class function TSession.Token: string;
var
  O: TJSObject;
begin
  Result := '';
  O := LeerSesion;
  if Assigned(O) and O.hasOwnProperty('access_token') then
    Result := string(O['access_token']);
end;

class function TSession.UserId: string;
var
  O: TJSObject;
begin
  Result := '';
  O := LeerSesion;
  if Assigned(O) and O.hasOwnProperty('user') then
    Result := string(TJSObject(O['user'])['id']);
end;

class function TSession.IsValid: Boolean;
var
  O: TJSObject;
  Vence, Ahora: Double;
begin
  Result := False;
  O := LeerSesion;
  if not (Assigned(O) and O.hasOwnProperty('expires_at')) then
    Exit;
  Vence := Double(O['expires_at']);
  Ahora := Double(TJSDate.now) / 1000;
  Result := (Vence - 30) > Ahora;
end;

end.
