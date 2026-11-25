unit uNavegacion;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Forms;

type
  TNavegacion = class
  private
    class var FEscuchando: Boolean;
  public
    class procedure Registrar(AForm: TWebForm);
    class procedure IrA(AClase: TWebFormClass);
    class function RutaActual: string; // lee #/ruta (por defecto 'vender')
    class procedure IrARuta(const ARuta: string; AReemplazar: Boolean = False);
    class procedure Iniciar;
  end;

implementation

uses
  uShell, uAjustes, fDashboard, fInventory, fAddProduct, fSecciones, fCobrar,
  fTasas, fAjustes,fHistorial;

function ClasePorRuta(const ARuta: string): TWebFormClass;
begin
  if ARuta = 'vender' then
    Result := TForm2
  else if ARuta = 'inventario' then
    Result := TForm3
  else if ARuta = 'agregar' then
    Result := TForm4
  else if ARuta = 'secciones' then
    Result := TForm5
  else if ARuta = 'cobrar' then
    Result := TForm6
  else if ARuta = 'tasas' then
    Result := TForm7
  else if ARuta = 'ajustes' then
    Result := TForm8
    else if ARuta = 'historial' then
  Result := TForm9
  else
    Result := nil;
end;

function AlCambiarHash(Event: TJSEvent): Boolean;
var
  Clase: TWebFormClass;
begin
  Result := True;
  Clase := ClasePorRuta(TNavegacion.RutaActual);
  if Clase <> nil then
    TNavegacion.IrA(Clase);
  // el formulario nuevo marca su pestaña en WebFormCreate
end;

class procedure TNavegacion.Registrar(AForm: TWebForm);
begin
  TShell.Actual := AForm;
end;

class function TNavegacion.RutaActual: string;
var
  H: string;
begin
  H := window.location.hash;
  if Copy(H, 1, 2) = '#/' then
    Result := Copy(H, 3, 50)
  else
    Result := 'vender';
end;

class procedure TNavegacion.IrARuta(const ARuta: string; AReemplazar: Boolean);
begin
  if AReemplazar then
    window.history.replaceState(nil, '', '#/' + ARuta)
    // no añade historial ni dispara hashchange
  else
    window.location.hash := '/' + ARuta; // añade historial y dispara hashchange
end;

class procedure TNavegacion.IrA(AClase: TWebFormClass);
var
  Anterior: TWebForm;

  procedure AlCrear(AForm: TObject);
  begin
    if Anterior <> nil then
      Anterior.Free;
    TShell.Activar(TShell.Destino);
    TShell.PonerInicial;
  end;

begin
  if (TShell.Actual <> nil) and (TShell.Actual.ClassType = AClase) then
    Exit;
  Anterior := TShell.Actual;
  TShell.Actual := AClase.CreateNew(@AlCrear);
end;

class procedure TNavegacion.Iniciar;
begin
  TAjustes.Aplicar;     // aplica el tema guardado en Ajustes
  TShell.AlNavegar := procedure(const Destino: string)
    begin
      if ClasePorRuta(Destino) <> nil then
        IrARuta(Destino)
      else
        console.log('Pantalla pendiente: ' + Destino);
      // caja, historial, tasas...
    end;

  if not FEscuchando then
  begin
    FEscuchando := True;
    window.addEventListener('hashchange', @AlCambiarHash);
  end;

  TShell.Iniciar;
end;

end.
