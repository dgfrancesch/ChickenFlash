unit uNavegacion;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Forms;

type
  TNavegacion = class
  private
    class var FActual: TWebForm;
  public
    class procedure Registrar(AForm: TWebForm);   // el formulario que está en pantalla
    class procedure IrA(AClase: TWebFormClass);
    class procedure Iniciar;                      // arranca el shell y conecta los destinos
  end;

implementation

uses
  uShell, fDashboard, fInventory;

class procedure TNavegacion.Registrar(AForm: TWebForm);
begin
  TShell.Actual := AForm;
end;

class procedure TNavegacion.IrA(AClase: TWebFormClass);
var
  Anterior: TWebForm;

    procedure AlCrear(AForm: TObject);
  begin
    if Anterior <> nil then
      Anterior.Free;
    TShell.Activar(TShell.Destino);   // si el Free se llevó el shell, se vuelve a crear
  end;

begin
  if (TShell.Actual <> nil) and (TShell.Actual.ClassType = AClase) then
    Exit;
  Anterior := TShell.Actual;
  TShell.Actual := AClase.CreateNew(@AlCrear);
end;

class procedure TNavegacion.Iniciar;
begin
  TShell.AlNavegar :=
    procedure(const Destino: string)
    begin
      if Destino = 'vender' then
        IrA(TForm2)
      else if Destino = 'inventario' then
        IrA(TForm3)
      else
        console.log('Pantalla pendiente: ' + Destino);   // caja, historial, tasas...
    end;
  TShell.Iniciar;
end;

end.
