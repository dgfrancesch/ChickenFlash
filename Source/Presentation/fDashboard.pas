unit fDashboard;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, Vcl.StdCtrls, WEBLib.StdCtrls, Vcl.Controls,
  WEBLib.WebCtrls;

type
  TForm2 = class(TWebForm)
    lblInicial: TWebHTMLDiv;
    divVenta: TWebHTMLDiv;
    divProductos: TWebHTMLDiv;
    btnVaciar: TWebButton;
    lblRed: TWebHTMLSpan;
    divFiltros: TWebHTMLDiv;
    dashboard: TWebHTMLDiv;
    btnCobrar: TWebButton;
    lblVentaAviso: TWebLabel;
    edtBuscar: TWebEdit;
    procedure WebFormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form2: TForm2;

implementation

uses
uSession, uAuthService, uPie, fLogin,uShell;

{$R *.dfm}

procedure TForm2.WebFormCreate(Sender: TObject);
var
  Nombre: string;
begin
  Nombre := TSession.UserName;
  document.getElementById('lblSaludo').innerHTML := 'Hola, ' + Nombre;
  lblInicial.ElementHandle.innerHTML := UpperCase(Copy(Nombre, 1, 1));
  TShell.Activar('vender');
  TShell.Actual := Self;
end;

end.