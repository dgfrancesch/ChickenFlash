unit fCobrar;

// Pantalla de cobro (ruta #/cobrar). Lee la venta armada en el dashboard desde
// sessionStorage ('venta'), deja elegir la forma de pago y al confirmar la registra
// solo muestra el resumen (por ahora no guarda nada en la base de datos).
// Las tasas salen de elToque (uTasas): al abrir se usa la última guardada y se consulta
// elToque; si responde, se actualiza la pantalla; si no, se queda la guardada.

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs, Vcl.StdCtrls, WEBLib.StdCtrls, WEBLib.WebCtrls,
  Vcl.Controls;

type
  TForm6 = class(TWebForm)
    cbForm: TWebHTMLDiv;
    cbDone: TWebHTMLDiv;
    cbTotal: TWebHTMLDiv;
    cbStatus: TWebHTMLDiv;
    cb: TWebHTMLDiv;
    cbDoneTxt: TWebLabel;
    cbTrf: TWebEdit;
    cbChCup: TWebEdit;
    cbNet: TWebHTMLSpan;
    cbChgSeg: TWebHTMLDiv;
    cbAllCash: TWebButton;
    cbAllTrf: TWebButton;
    cbFx: TWebEdit;
    cbMsg: TWebHTMLDiv;
    cbBack: TWebButton;
    cbChFxL: TWebHTMLSpan;
    cbChg: TWebHTMLDiv;
    cbOk: TWebButton;
    cbChFx: TWebEdit;
    cbCash: TWebEdit;
    cbMlc: TWebEdit;
    cbAgain: TWebButton;
    cbBrk: TWebHTMLDiv;
    cbFxSeg: TWebHTMLDiv;
    cbRates: TWebHTMLSpan;
    procedure WebFormCreate(Sender: TObject);
  private
    [async]
    procedure ActualizarTasas;
  public
  end;

var
  Form6: TForm6;

implementation

uses
  uShell, uTasas;

{$R *.dfm}

function Por(const Id: string): TJSElement;
begin
  Result := document.getElementById(Id);
end;

// Texto que se muestra junto a las tasas
function EstadoDe(T: TTasasCup): string;
begin
  if T.Origen = 'toque' then
    Result := 'actualizada ' + T.Hora
  else if T.Origen = 'guardada' then
    Result := 'sin conexión, guardada de las ' + T.Hora
  else
    Result := 'SIN CONEXIÓN: tasa de ejemplo, no es real';
end;

// Deja las tasas listas para cuando se abra la pantalla (la primera vez)
procedure PonerTasas(ValUsd, ValEur, ValMlc: Double; const Estado: string; Aviso: Boolean);
begin
  asm
    window.CFTasas = { USD: ValUsd, EUR: ValEur, MLC: ValMlc, estado: Estado, aviso: Aviso };
  end;
end;

// Cambia las tasas con la pantalla ya abierta y recalcula todo
procedure AplicarTasas(ValUsd, ValEur, ValMlc: Double; const Estado: string; Aviso: Boolean);
begin
  asm
    if (window.CFCobro) {
      window.CFCobro.tasas({ USD: ValUsd, EUR: ValEur, MLC: ValMlc }, Estado, Aviso);
    }
  end;
end;

// Toda la logica de la pantalla esta en JavaScript dentro de un asm.
procedure InstalarCobro;
begin
  asm
    (function () {
      // Puede haber otro #cb (el del dashboard, que aun no se libera): se usa el ultimo,
      // que es el de esta pantalla, y todo se busca solo dentro de el.
      var todos = document.querySelectorAll('[id="cb"]');
      var root = todos.length ? todos[todos.length - 1] : null;
      if (!root) { return; }

      var g = function (id) { return root.querySelector('[id="' + id + '"]'); };
      var TOTAL = 0, VENTA = null;
      var R = { USD: 400, EUR: 430, MLC: 280 };
      var fxC = 'USD', chC = 'CUP', man = null;

      var n = function (id) {
        var v = parseFloat(String(g(id).value).replace(',', '.'));
        return isNaN(v) || v < 0 ? 0 : v;
      };
      var f = function (x, d) {
        d = d || 0;
        return x.toLocaleString('es', { minimumFractionDigits: d, maximumFractionDigits: d }).replace(/\u00a0|\u202f/g, ' ');
      };
      var fl = function (x, d) { return Math.floor(x * Math.pow(10, d) + 1e-9) / Math.pow(10, d); };
      var r2 = function (x) { return Math.round(x * 100) / 100; };
      var sel = function (seg, c) {
        var bs = g(seg).querySelectorAll('button');
        for (var i = 0; i < bs.length; i++) {
          bs[i].classList.toggle('sel', bs[i].getAttribute('data-c') === c);
        }
      };

      // Linea de tasas: de donde salen y de cuando son (en naranja si no son recientes)
      var rotulo = function (estado, aviso) {
        g('cbRates').textContent = 'Tasa elToque (' + estado + '): 1 USD = ' + R.USD + ' CUP \u00b7 1 EUR = ' + R.EUR + ' CUP \u00b7 1 MLC = ' + R.MLC + ' CUP';
        g('cbRates').style.color = aviso ? 'var(--cb-warn)' : '';
      };

      var calc = function () {
        var cash = n('cbCash'), fx = n('cbFx'), trf = n('cbTrf'), mlc = n('cbMlc');
        var fxCup = fx * R[fxC], mlcCup = mlc * R.MLC;
        var sc = cash + fxCup, st = trf + mlcCup, paid = sc + st;
        return { cash: cash, fx: fx, trf: trf, mlc: mlc, fxCup: fxCup, mlcCup: mlcCup, sc: sc, st: st, paid: paid, diff: paid - TOTAL };
      };
      var totalText = function (diff) {
        if (chC === 'CUP' || !calc().fx) { return f(diff) + ' CUP'; }
        return f(fl(diff / R[chC], 2), 2) + ' ' + chC;
      };
      var getSplit = function (diff) {
        var r = R[chC], fx, cup;
        if (man && man.field === 'fx') { fx = Math.min(man.v, diff / r); cup = diff - fx * r; }
        else if (man) { cup = Math.min(man.v, diff); fx = (diff - cup) / r; }
        else { fx = Math.floor(diff / r + 1e-9); cup = diff - fx * r; }
        return { fx: Math.round(fx * 100) / 100, cup: Math.max(0, Math.round(cup)) };
      };
      var changeText = function (diff) {
        if (chC === 'CUP' || !calc().fx) { return f(diff) + ' CUP'; }
        var sp = getSplit(diff), P = [];
        if (sp.fx > 0) { P.push(f(sp.fx, sp.fx % 1 ? 2 : 0) + ' ' + chC); }
        if (sp.cup > 0) { P.push(f(sp.cup) + ' CUP'); }
        return P.length ? P.join(' + ') : '0 CUP';
      };
      var fillSplit = function (which) {
        var d = calc().diff, sp = getSplit(d);
        if (which !== 'fx') { g('cbChFx').value = sp.fx ? String(sp.fx) : ''; }
        if (which !== 'cup') { g('cbChCup').value = sp.cup ? String(sp.cup) : ''; }
        var over = man && ((man.field === 'fx' && man.v * R[chC] > d + 0.01) || (man.field === 'cup' && man.v > d + 0.01));
        g('cbChgAmt').textContent = over
          ? 'No puedes devolver m\u00e1s del vuelto total (' + totalText(d) + ')'
          : 'Vuelto total: ' + totalText(d) + ' = ' + f(d) + ' CUP';
      };

      var upd = function () {
        man = null;
        var c = calc();
        g('cbFxEq').textContent = c.fx
          ? f(c.fx, 2) + ' ' + fxC + ' \u00d7 ' + R[fxC] + ' = ' + f(c.fxCup) + ' CUP'
          : '1 ' + fxC + ' = ' + R[fxC] + ' CUP';
        g('cbMlcEq').textContent = c.mlc
          ? f(c.mlc, 2) + ' MLC \u00d7 ' + R.MLC + ' = ' + f(c.mlcCup) + ' CUP'
          : 'Cuenta como transferencia';
        g('cbSumCash').textContent = f(c.sc) + ' CUP';
        g('cbSumTrf').textContent = f(c.st) + ' CUP';
        var fill = g('cbFill'), s = g('cbStatus');
        fill.style.width = Math.min(100, TOTAL > 0 ? c.paid / TOTAL * 100 : 0) + '%';
        var showChg = c.diff > 0.005 && c.fx > 0;
        if (!showChg && chC !== 'CUP') { chC = 'CUP'; sel('cbChgSeg', 'CUP'); }
        if (c.diff < -0.005) {
          fill.style.background = 'var(--cb-warn)'; s.style.color = 'var(--cb-warn)';
          s.textContent = 'Faltan ' + f(-c.diff) + ' CUP';
        } else if (c.diff <= 0.005) {
          fill.style.background = 'var(--cb-ok)'; s.style.color = 'var(--cb-ok)';
          s.textContent = 'Pago completo';
        } else {
          fill.style.background = 'var(--cb-gold)'; s.style.color = 'var(--cb-gold)';
          s.textContent = 'Vuelto: ' + totalText(c.diff);
        }
        g('cbChg').classList.toggle('cb-hide', !showChg);
        if (showChg) {
          g('cbBrk').classList.toggle('cb-hide', chC === 'CUP');
          g('cbChFxL').textContent = 'Entregas en ' + chC;
          fillSplit();
        }
        g('cbMsg').textContent = '';
      };

      var setAll = function (id) {
        var ids = ['cbCash', 'cbFx', 'cbTrf', 'cbMlc'];
        for (var i = 0; i < ids.length; i++) { g(ids[i]).value = ''; }
        g(id).value = TOTAL;
        upd();
      };

      var abrir = function () {
        var v = null;
        try { v = JSON.parse(sessionStorage.getItem('venta') || 'null'); } catch (e) { v = null; }
        if (!v || !v.items || !v.items.length) { return false; }
        VENTA = v;
        TOTAL = r2(Number(v.total));
        var t = window.CFTasas || R;
        R = { USD: Number(t.USD), EUR: Number(t.EUR), MLC: Number(t.MLC) };

        g('cbTotal').textContent = f(TOTAL, TOTAL % 1 ? 2 : 0) + ' CUP';
        var partes = [];
        for (var i = 0; i < v.items.length; i++) {
          var it = v.items[i];
          partes.push(it.nombre + ' \u00d7' + it.cantidad + (it.unidad === 'lb' ? ' lb' : ''));
        }
        g('cbItems').textContent = partes.join(' \u00b7 ');
        rotulo(t.estado || 'consultando...', !!t.aviso);
        g('cbNet').textContent = navigator.onLine ? 'En l\u00ednea' : 'Sin conexi\u00f3n';
        g('cbNet').style.color = navigator.onLine ? '' : 'var(--cb-warn)';
        sel('cbFxSeg', 'USD'); sel('cbChgSeg', 'CUP');
        upd();
        root.classList.add('cb-open');
        root.scrollTop = 0;
        return true;
      };

      var confirmar = function () {
        var c = calc();
        if (c.diff < -0.005) {
          g('cbMsg').textContent = 'A\u00fan faltan ' + f(-c.diff) + ' CUP para completar el pago.';
          return;
        }
        var L = [['Total', '<b>' + f(TOTAL) + ' CUP</b>']];
        if (c.cash) { L.push(['Efectivo (CUP)', '<b>' + f(c.cash) + ' CUP</b>']); }
        if (c.fx) { L.push(['Divisa en efectivo', '<b>' + f(c.fx, 2) + ' ' + fxC + '</b> (' + f(c.fxCup) + ' CUP)']); }
        if (c.trf) { L.push(['Transferencia (CUP)', '<b>' + f(c.trf) + ' CUP</b>']); }
        if (c.mlc) { L.push(['MLC (transferencia)', '<b>' + f(c.mlc, 2) + ' MLC</b> (' + f(c.mlcCup) + ' CUP)']); }
        if (c.diff > 0.005) { L.push(['Vuelto entregado', '<b>' + changeText(c.diff) + '</b>']); }
        g('cbDoneTxt').innerHTML = L.map(function (x) { return x[0] + ': ' + x[1]; }).join('<br>');
        try { sessionStorage.removeItem('venta'); } catch (e) { }
        g('cbMsg').textContent = '';
        g('cbForm').classList.add('cb-hide');
        g('cbDone').classList.remove('cb-hide');
        root.scrollTop = 0;
      };

      root.addEventListener('click', function (e) {
        var b = e.target && e.target.closest ? e.target.closest('button') : null;
        if (!b) { return; }
        var id = b.id, pid = b.parentNode ? b.parentNode.id : '';
        if (id === 'cbBack' || id === 'cbAgain') { window.location.hash = '/vender'; }
        else if (id === 'cbAllCash') { setAll('cbCash'); }
        else if (id === 'cbAllTrf') { setAll('cbTrf'); }
        else if (id === 'cbOk') { confirmar(); }
        else if (pid === 'cbFxSeg') { fxC = b.getAttribute('data-c'); sel('cbFxSeg', fxC); upd(); }
        else if (pid === 'cbChgSeg') { chC = b.getAttribute('data-c'); sel('cbChgSeg', chC); upd(); }
      });

      root.addEventListener('input', function (e) {
        var id = e.target ? e.target.id : '';
        if (id === 'cbCash' || id === 'cbFx' || id === 'cbTrf' || id === 'cbMlc') { upd(); }
        else if (id === 'cbChFx') { man = { field: 'fx', v: n('cbChFx') }; fillSplit('fx'); }
        else if (id === 'cbChCup') { man = { field: 'cup', v: n('cbChCup') }; fillSplit('cup'); }
      });

      // Para que Pascal cambie las tasas cuando elToque responde (no si la venta ya se confirmo)
      window.CFCobro = {
        tasas: function (t, estado, aviso) {
          if (!g('cbDone').classList.contains('cb-hide')) { return; }
          R = { USD: Number(t.USD), EUR: Number(t.EUR), MLC: Number(t.MLC) };
          rotulo(estado, aviso);
          upd();
        }
      };

      if (!abrir()) { window.location.hash = '/vender'; }
    })();
  end;
end;

procedure TForm6.WebFormCreate(Sender: TObject);
var
  T: TTasasCup;
  Estado: string;
begin
  TShell.Actual := Self;
  TShell.Activar('vender');                    // la barra inferior sigue marcando Vender

  // La pantalla abre ya con la última tasa guardada; elToque se consulta detrás
  T := TTasas.Guardada;
  if T.Origen = 'ejemplo' then
    Estado := 'sin tasa guardada, consultando...'
  else
    Estado := 'consultando...';
  PonerTasas(T.Usd, T.Eur, T.Mlc, Estado, T.Origen = 'ejemplo');
  InstalarCobro;
  ActualizarTasas;
end;

procedure TForm6.ActualizarTasas;
var
  T: TTasasCup;
begin
  T := await(TTasasCup, TTasas.Consultar);
  if TShell.Actual <> Self then Exit;          // ya saliste de esta pantalla
  AplicarTasas(T.Usd, T.Eur, T.Mlc, EstadoDe(T), T.Origen <> 'toque');
end;

end.
