unit fInventory;

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs;

type
  TForm3 = class(TWebForm)
    procedure WebFormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form3: TForm3;

implementation

uses
  uShell;

{$R *.dfm}

procedure TForm3.WebFormCreate(Sender: TObject);
begin
  TShell.Activar('inventario');
  TShell.Actual := Self;
end;

end.
