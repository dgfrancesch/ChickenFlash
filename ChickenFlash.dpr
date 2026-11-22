program ChickenFlash;

{$R *.dres}

uses
  Web,
  WEBLib.Forms,
  uAuthService in 'Source\Domain\Services\uAuthService.pas',
  fLogin in 'Source\Presentation\fLogin.pas' {Form1: TWebForm} {*.html},
  uConfig in 'Source\Infraestructure\uConfig.pas',
  uHttp in 'Source\Infraestructure\uHttp.pas',
  uSession in 'Source\Infraestructure\uSession.pas',
  fDashboard in 'Source\Presentation\fDashboard.pas' {Form2: TWebForm} {*.html},
  uPie in 'Source\Presentation\uPie.pas',
  fInventory in 'Source\Presentation\fInventory.pas' {Form3: TWebForm} {*.html},
  uShell in 'Source\Presentation\uShell.pas',
  uNavegacion in 'Source\Presentation\uNavegacion.pas',
  fAddProduct in 'Source\Presentation\fAddProduct.pas' {Form4: TWebForm} {*.html},
  uInventarioService in 'Source\Domain\Services\uInventarioService.pas',
  uDom in 'Source\Infraestructure\uDom.pas',
  fSecciones in 'Source\Presentation\fSecciones.pas' {Form5: TWebForm} {*.html};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  if TAuthService.HaySesion then
  begin
    TNavegacion.Iniciar;
    TNavegacion.IrARuta(TNavegacion.RutaActual, True); // normaliza la URL
        if TNavegacion.RutaActual = 'inventario' then
      Application.CreateForm(TForm3, Form3)
    else if TNavegacion.RutaActual = 'agregar' then
      Application.CreateForm(TForm4, Form4)
    else if TNavegacion.RutaActual = 'secciones' then
      Application.CreateForm(TForm5, Form5)
    else
      Application.CreateForm(TForm2, Form2);
  end
  else
  begin
    window.history.replaceState(nil, '', window.location.pathname + window.location.search);
    Application.CreateForm(TForm1, Form1);
  end;
  Application.Run;
end.
