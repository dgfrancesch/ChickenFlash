unit fHistorial;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, WEBLib.WebCtrls, Vcl.StdCtrls, WEBLib.StdCtrls,
  Vcl.Controls;

type
  TForm9 = class(TWebForm)
    hvList: TWebHTMLDiv;
    hvRoot: TWebHTMLDiv;
    lblInicial: TWebHTMLDiv;
    hvBusca: TWebEdit;
    hvChips: TWebHTMLDiv;
    procedure WebFormCreate(Sender: TObject);
  end;

var
  Form9: TForm9;

implementation

{$R *.dfm}

uses
  uShell, uNavegacion, uHttp, uSession;



procedure TForm9.WebFormCreate(Sender: TObject);
begin
  TNavegacion.Registrar(Self);
  TShell.Activar('mas');

 { IniciarEstado;
  El('hvRoot').addEventListener('click', @AlClic);
  El('hvBusca').addEventListener('input', @AlBuscar);
  Cargar; // por defecto: filtro "Hoy"  }
end;

end.
