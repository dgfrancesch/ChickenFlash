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
  end;

  THttp = class
  public
    [async]
    class function Send(const Method, Path, Body, Token: string): TApiResponse;
  end;

implementation

uses
  uConfig;

class function THttp.Send(const Method, Path, Body, Token: string): TApiResponse;
var
  Req: TWebHttpRequest;
  Xhr: TJSXMLHttpRequest;
begin
  Result := TApiResponse.Create;
  Req := TWebHttpRequest.Create(nil);
  try
    Req.Headers.Clear;
    Req.Headers.AddPair('apikey', SB_KEY);
    Req.Headers.AddPair('Content-Type', 'application/json');
    if Token <> '' then
      Req.Headers.AddPair('Authorization', 'Bearer ' + Token);

    if Method = 'POST' then
    begin
      Req.Command := httpPOST;
      Req.PostData := Body;
    end
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
end;

end.
