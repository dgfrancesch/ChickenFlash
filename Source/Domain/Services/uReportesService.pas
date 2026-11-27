unit uReportesService;

interface

uses
  System.SysUtils, JS, Web, uHttp;

type
  TResultadoReporte = class
  public
    Ok: Boolean;
    Error: string;
    Json: string;      // objeto devuelto por reporte_resumen
  end;

  TReportesService = class
  public
    // Periodo: 'hoy', 'semana' o 'mes'
    [async]
    class function Cargar(const Periodo: string): TResultadoReporte;
  end;

implementation

uses
  uSession;

class function TReportesService.Cargar(const Periodo: string): TResultadoReporte;
var
  R: TApiResponse;
begin
  Result := TResultadoReporte.Create;
  Result.Json := '{}';
  // GET (la función es STABLE) para que uHttp pueda servirla desde su copia local sin conexión
  R := await(TApiResponse, THttp.Send('GET',
    '/rest/v1/rpc/reporte_resumen?p_periodo=' + Periodo, '', TSession.Token));
  if not R.Ok then
  begin
    console.log('Error BD ' + IntToStr(R.Status) + ': ' + R.Body);   // detalle técnico
    if Pos('solo admin', R.Body) > 0 then
      Result.Error := 'Tu usuario no es admin, no puede ver reportes.'
    else
      case R.Status of
        0:   Result.Error := 'Sin conexión y sin copia guardada del reporte.';
        401: Result.Error := 'Tu sesión venció. Vuelve a iniciar sesión.';
        403: Result.Error := 'No tienes permiso para ver reportes.';
      else
        Result.Error := 'No se pudo cargar el reporte.';
      end;
    Exit;
  end;
  Result.Json := R.Body;
  Result.Ok := True;
end;

end.
