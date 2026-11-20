unit uPie;

interface

procedure PonerPie(const IdPie: string);

implementation

uses
  System.SysUtils, DateUtils, JS, Web;

procedure PonerPie(const IdPie: string);
var
  E: TJSElement;
begin
  E := document.getElementById(IdPie);
  if E <> nil then
    E.innerHTML := '&copy; ' + IntToStr(YearOf(Now)) +
      ' Chicken Flash • Sistema de Punto de Venta e Inventario';
end;

end.
