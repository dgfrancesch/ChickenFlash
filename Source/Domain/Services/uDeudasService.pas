unit uDeudasService;

interface

uses
  System.SysUtils, JS, Web, uHttp;

type
  TResultadoDeudas = class
  public
    Ok: Boolean;
    Error: string;
    Json: string;      // arreglo de deudores tal como lo devuelve deudores_con_saldo
  end;

  TResultadoPago = class
  public
    Ok: Boolean;
    Error: string;
    Restante: Double;  // saldo que queda en CUP (0 = deuda saldada)
  end;

  TDeudasService = class
  public
    // Deudores con sus deudas, productos y abonos (función deudores_con_saldo)
    [async]
    class function Cargar: TResultadoDeudas;
    // Registra un abono o el pago completo con la función pagar_deuda.
    // PagosJson: [{"metodo":"efectivo","moneda":"CUP","monto":500,"tasa_cup":1}, ...]
    [async]
    class function Pagar(DeudaId: Integer; const PagosJson: string): TResultadoPago;
  end;

implementation

uses
  uSession;

class function TDeudasService.Cargar: TResultadoDeudas;
var
  R: TApiResponse;
begin
  Result := TResultadoDeudas.Create;
  Result.Json := '[]';
  // GET (la función es STABLE) para que uHttp pueda servirla desde su copia local sin conexión
  R := await(TApiResponse, THttp.Send('GET', '/rest/v1/rpc/deudores_con_saldo',
    '', TSession.Token));
  if not R.Ok then
  begin
    console.log('Error BD ' + IntToStr(R.Status) + ': ' + R.Body);   // detalle técnico
    case R.Status of
      0:   Result.Error := 'Sin conexión y sin copia guardada de las deudas.';
      401: Result.Error := 'Tu sesión venció. Vuelve a iniciar sesión.';
    else
      Result.Error := 'No se pudieron cargar las deudas.';
    end;
    Exit;
  end;
  Result.Json := R.Body;
  Result.Ok := True;
end;

class function TDeudasService.Pagar(DeudaId: Integer; const PagosJson: string): TResultadoPago;
var
  R: TApiResponse;
begin
  Result := TResultadoPago.Create;
  R := await(TApiResponse, THttp.Send('POST', '/rest/v1/rpc/pagar_deuda',
    '{"p_deuda_id":' + IntToStr(DeudaId) + ',"p_pagos":' + PagosJson + '}', TSession.Token));
  Result.Ok := R.Ok;
  if R.Ok then
  begin
    if Trim(R.Body) <> '' then
      Result.Restante := Double(TJSJSON.parse(R.Body));   // numeric devuelto tal cual: 1200.00
    Exit;
  end;

  console.log('Error BD ' + IntToStr(R.Status) + ': ' + R.Body);
  if Pos('no autorizado', R.Body) > 0 then
    Result.Error := 'Tu usuario no es admin, no puede cobrar deudas.'
  else if Pos('no hay caja abierta', R.Body) > 0 then
    Result.Error := 'Abre la caja antes de cobrar una deuda.'
  else if Pos('excede el saldo', R.Body) > 0 then
    Result.Error := 'El abono es mayor que el saldo de la deuda.'
  else if Pos('no está pendiente', R.Body) > 0 then
    Result.Error := 'Esa deuda ya no está pendiente. Actualiza la lista.'
  else if Pos('no existe', R.Body) > 0 then
    Result.Error := 'La deuda no existe. Actualiza la lista.'
  else
    case R.Status of
      0:   Result.Error := 'Sin conexión. El pago NO se guardó; intenta de nuevo.';
      401: Result.Error := 'Tu sesión venció. Vuelve a iniciar sesión.';
      403: Result.Error := 'No tienes permiso para cobrar deudas.';
    else
      Result.Error := 'No se pudo registrar el pago (' + IntToStr(R.Status) + ').';
    end;
end;

end.
