unit uVentasService;

interface

uses
  System.SysUtils, JS, Web, uHttp;

type
  TResultadoMonto = class
  public
    Ok: Boolean;
    Error: string;
    Valor: Double;
  end;

  TVentasService = class
  public
    // Suma de las ventas completadas desde las 00:00 de hoy (hora del dispositivo)
    [async]
    class function VentasDeHoy: TResultadoMonto;
  end;

implementation

uses
  uSession;

function InicioDelDia: string;
begin
  asm
    var d = new Date();
    d.setHours(0, 0, 0, 0);
    Result = d.toISOString();
  end;
end;

class function TVentasService.VentasDeHoy: TResultadoMonto;
var
  R: TApiResponse;
  Arr: TJSArray;
  i: Integer;
  Suma: Double;
begin
  Result := TResultadoMonto.Create;
  R := await(TApiResponse, THttp.Send('GET',
    '/rest/v1/ventas?select=total_cup&estado=eq.completada&fecha=gte.' + InicioDelDia,
    '', TSession.Token));
  if not R.Ok then
  begin
    console.log('Error BD ' + IntToStr(R.Status) + ': ' + R.Body);   // detalle técnico
    Result.Error := 'No se pudieron cargar las ventas de hoy.';
    Exit;
  end;

  Arr := TJSArray(TJSJSON.parse(R.Body));
  Suma := 0;
  for i := 0 to Arr.length - 1 do
    Suma := Suma + Double(TJSObject(Arr[i])['total_cup']);
  Result.Valor := Suma;
  Result.Ok := True;
end;

end.
