unit fInventory;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, WEBLib.StdCtrls, WEBLib.ExtCtrls, Vcl.Controls,
  Vcl.StdCtrls, WEBLib.WebCtrls;

type
  TForm3 = class(TWebForm)
    divModal: TWebHTMLDiv;
    lblInicial: TWebHTMLDiv;
    lblRed: TWebHTMLSpan;
    divFiltros: TWebHTMLDiv;
    btnKpiBajo: TWebButton;
    btnAgregar: TWebButton;
    btnUniLb: TWebButton;
    btnEditarSecciones: TWebButton;
    btnEliminar: TWebButton;
    edtNombre: TWebEdit;
    btnVisible: TWebButton;
    btnQuitarFoto: TWebButton;
    btnFoto: TWebButton;
    divSheet: TWebHTMLDiv;
    lblEliminar: TWebHTMLSpan;
    btnCancelar: TWebButton;
    divSeccion: TWebHTMLDiv;
    lblGuardar: TWebHTMLSpan;
    lblModalTitulo: TWebLabel;
    divLista: TWebHTMLDiv;
    btnTodos: TWebButton;
    edtDetalle: TWebEdit;
    btnGuardar: TWebButton;
    imgFoto: TWebImageControl;
    edtPrecio: TWebSpinEdit;
    divToast: TWebHTMLDiv;
    divFotoPrev: TWebHTMLDiv;
    edtStock: TWebSpinEdit;
    btnCambiarFoto: TWebButton;
    btnUniPaq: TWebButton;
    btnKpiActivos: TWebButton;
    edtBuscar: TWebEdit;
    lblToast: TWebHTMLSpan;
    btnCerrar: TWebButton;
    divInventario: TWebHTMLDiv;
    divSecciones: TWebHTMLDiv;
    procedure WebFormCreate(Sender: TObject);
    procedure btnAgregarClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form3: TForm3;

implementation

uses
  uShell, uSession,uNavegacion;

{$R *.dfm}

procedure TForm3.btnAgregarClick(Sender: TObject);
begin
  TNavegacion.IrARuta('agregar');
end;

procedure TForm3.WebFormCreate(Sender: TObject);
begin
  lblInicial.HTML.Text := UpperCase(Copy(TSession.UserName, 1, 1));
  TShell.Activar('inventario');
  TShell.Actual := Self;
end;

end.
