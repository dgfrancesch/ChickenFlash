unit uAjustes;

// Configuración de la app, guardada en localStorage ('cfajustes').
// No usa el prefijo "cf:", así que no se borra al cerrar sesión.

interface

uses
  System.SysUtils, JS, Web;

type
  TAjustes = class
  public
    class function Tema: string;                       // 'dark' | 'light'
    class procedure PonerTema(const V: string);
    class procedure Aplicar;                           // pone el tema en el documento

    class function UsarToque: Boolean;
    class procedure PonerUsarToque(V: Boolean);
    class function MonedaActiva(const Mon: string): Boolean;   // 'usd' | 'eur' | 'mlc'
    class procedure PonerMonedaActiva(const Mon: string; V: Boolean);
    class function TasaManual(const Mon: string): Double;      // 0 = sin definir
    class procedure PonerTasaManual(const Mon: string; V: Double);
    class function MonedaBase: string;                 // moneda marcada por defecto en el conversor
    class procedure PonerMonedaBase(const V: string);

    class function LimiteStock: Integer;
    class procedure PonerLimiteStock(V: Integer);
    class function StockBajo(Stock: Double): Boolean;
  end;

implementation

function Leer(const Clave, Defecto: string): string;
begin
  asm
    try {
      var v = localStorage.getItem('cfaj_' + Clave);
      Result = (v !== null) ? v : Defecto;
    } catch (e) { Result = Defecto; }
  end;
end;

procedure Escribir(const Clave, Valor: string);
begin
  asm
    try { localStorage.setItem('cfaj_' + Clave, Valor); } catch (e) {}
  end;
end;

function AFloat(const S: string; Def: Double): Double;
begin
  asm
    var n = parseFloat(S);
    Result = isNaN(n) ? Def : n;
  end;
end;

function Texto(V: Double): string;
begin
  asm
    Result = String(V);
  end;
end;

function TemaDelDocumento: string;
begin
  asm
    Result = document.documentElement.getAttribute('data-theme') === 'light' ? 'light' : 'dark';
  end;
end;

class function TAjustes.Tema: string;
begin
  Result := Leer('tema', '');
  if Result = '' then
    Result := TemaDelDocumento;
end;

class procedure TAjustes.PonerTema(const V: string);
begin
  Escribir('tema', V);
end;

class procedure TAjustes.Aplicar;
begin
  // solo si el usuario ya eligió un tema en Ajustes
  if Leer('tema', '') <> '' then
    document.documentElement.setAttribute('data-theme', Leer('tema', 'dark'));
end;

class function TAjustes.UsarToque: Boolean;
begin
  Result := Leer('toque', '1') = '1';
end;

class procedure TAjustes.PonerUsarToque(V: Boolean);
begin
  if V then Escribir('toque', '1') else Escribir('toque', '0');
end;

class function TAjustes.MonedaActiva(const Mon: string): Boolean;
begin
  Result := Leer('act_' + Mon, '1') = '1';
end;

class procedure TAjustes.PonerMonedaActiva(const Mon: string; V: Boolean);
begin
  if V then Escribir('act_' + Mon, '1') else Escribir('act_' + Mon, '0');
end;

class function TAjustes.TasaManual(const Mon: string): Double;
begin
  Result := AFloat(Leer('tasa_' + Mon, ''), 0);
end;

class procedure TAjustes.PonerTasaManual(const Mon: string; V: Double);
begin
  Escribir('tasa_' + Mon, Texto(V));
end;

class function TAjustes.MonedaBase: string;
begin
  Result := Leer('base', 'usd');
end;

class procedure TAjustes.PonerMonedaBase(const V: string);
begin
  Escribir('base', V);
end;

class function TAjustes.LimiteStock: Integer;
begin
  Result := Trunc(AFloat(Leer('stock', '8'), 8));
end;

class procedure TAjustes.PonerLimiteStock(V: Integer);
begin
  Escribir('stock', IntToStr(V));
end;

class function TAjustes.StockBajo(Stock: Double): Boolean;
begin
  Result := Stock <= LimiteStock;
end;

end.
