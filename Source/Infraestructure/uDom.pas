unit uDom;

// Ayudas pequeñas para tocar el HTML desde las pantallas.

interface

uses
  System.SysUtils, JS, Web;

function Ancestro(El: TJSElement; const Selector: string): TJSElement;
function Clonar(const IdMolde: string): TJSElement;
function Esc(const S: string): string;
function Numero(V: Double; Decimales: Integer): string;
function Miles(V: Double): string;
procedure PonerClase(El: TJSElement; const Clase: string; Si: Boolean);
procedure Mostrar(El: TJSElement; Visible: Boolean);

implementation

// Busca el elemento (o su ancestro) que cumple el selector; nil si no hay
function Ancestro(El: TJSElement; const Selector: string): TJSElement;
begin
  asm
    Result = El.closest(Selector);
  end;
end;

// Copia el primer elemento de un <template> del HTML; nil si no existe
function Clonar(const IdMolde: string): TJSElement;
begin
  asm
    var t = document.getElementById(IdMolde);
    Result = (t && t.content && t.content.firstElementChild)
      ? t.content.firstElementChild.cloneNode(true) : null;
  end;
end;

// Escapa texto para meterlo dentro de HTML
function Esc(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

// Número sin ceros de más, con 2 o 3 decimales como máximo
function Numero(V: Double; Decimales: Integer): string;
var
  F: Double;
begin
  if Decimales = 3 then F := 1000 else F := 100;
  Result := FloatToStr(Round(V * F) / F);
end;

// Dinero con espacio entre miles y hasta 2 decimales: 12 300 / 450.5
function Miles(V: Double): string;
begin
  asm
    Result = Number(V).toLocaleString('en-US', {maximumFractionDigits: 2}).replace(/,/g, ' ');
  end;
end;

procedure PonerClase(El: TJSElement; const Clase: string; Si: Boolean);
begin
  if Si then
    El.classList.add(Clase)
  else
    El.classList.remove(Clase);
end;

procedure Mostrar(El: TJSElement; Visible: Boolean);
begin
  if Visible then
    El.removeAttribute('hidden')
  else
    El.setAttribute('hidden', '');
end;

end.
