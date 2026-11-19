program ChickenFlash;



uses
  Vcl.Forms,
  WEBLib.Forms,
  uAuthService in 'Source\Domain\Services\uAuthService.pas',
  fLogin in 'Source\Presentation\fLogin.pas' {Form1: TWebForm} {*.html},
  uConfig in 'Source\Infraestructure\uConfig.pas',
  uHttp in 'Source\Infraestructure\uHttp.pas',
  uSession in 'Source\Infraestructure\uSession.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
