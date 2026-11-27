unit fReportes;

// Pantalla de reportes (ruta #/reportes). Pascal solo hace de puente con la BD
// (uReportesService); la pantalla vive en JavaScript dentro de un asm, igual que fDeudas.

interface

uses
  System.SysUtils, System.Classes, JS, Web, WEBLib.Graphics, WEBLib.Controls,
  WEBLib.Forms, WEBLib.Dialogs;

type
  TForm12 = class(TWebForm)
    procedure WebFormCreate(Sender: TObject);
  end;

var
  Form12: TForm12;

implementation

uses
  uShell, uNavegacion, uReportesService;

{$R *.dfm}

type
  TCargarFn = procedure(const Periodo: string; Cb: TJSFunction);

[async]
procedure CargarInterno(const Periodo: string; Cb: TJSFunction);
var
  R: TResultadoReporte;
  Ok: Boolean;
  Err, Json: string;
begin
  try
    R := await(TResultadoReporte, TReportesService.Cargar(Periodo));
    Ok := R.Ok;
    Err := R.Error;
    Json := R.Json;
  except
    Ok := False;
    Err := 'No se pudo cargar el reporte.';
    Json := '{}';
  end;
  asm
    Cb(Ok, Err, Json);
  end;
end;

procedure CargarPuente(const Periodo: string; Cb: TJSFunction);
begin
  CargarInterno(Periodo, Cb);
end;

procedure PonerPuentes;
var
  FnC: TCargarFn;
begin
  FnC := @CargarPuente;
  asm
    window.CFRCargar = FnC;
  end;
end;

procedure InstalarReportes;
begin
  asm
    (function () {
      var todos = document.querySelectorAll('[id="rp"]');
      var root = todos.length ? todos[todos.length - 1] : null;
      if (!root) { return; }
      var g = function (id) { return root.querySelector('[id="' + id + '"]'); };

      var period = 'semana', mode = 'top', D = null, seq = 0, avisoT = 0;
      var PER = { hoy: 'ayer', semana: 'sem. ant.', mes: 'mes ant.' };
      var UN = { peso: 'lb', paquete_peso: 'paq', unidad: 'ud' };
      var COL = ['gold', 'teal', 'ok', 'warn'];

      var num = function (x) { x = Number(x); return isNaN(x) ? 0 : x; };
      var fmt = function (x, d) {
        var s = Number(x).toFixed(d || 0);
        if (d) { s = s.replace(/\.?0+$/, ''); }
        var p = s.split('.');
        p[0] = p[0].replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
        return p.join('.');
      };
      var cup = function (x) { return fmt(Math.round(x)) + ' CUP'; };
      var esc = function (s) {
        return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;')
          .replace(/>/g, '&gt;').replace(/\x22/g, '&quot;');
      };
      var vacio = function (t) { return '<div class="rp-empty">' + t + '</div>'; };
      var qtxt = function (q, tv) { return fmt(num(q), 2) + ' ' + (UN[tv] || ''); };
      var cell = function (c) {
        return '<div class="rp-cell"><small>' + c[0] + '</small><b class="' + c[2] + '">' + c[1] + '</b></div>';
      };

      var aviso = function (txt) {
        var a = g('rpAviso');
        a.textContent = txt;
        a.hidden = false;
        clearTimeout(avisoT);
        avisoT = setTimeout(function () { a.hidden = true; }, 6000);
      };

      var render = function () {
        if (!D) { return; }
        var k = D.kpis || {};
        var ventas = num(k.ventas), ant = num(k.ventas_ant), gan = num(k.ganancia), tk = num(k.tickets);

        g('rpSales').textContent = cup(ventas);
        var dl = g('rpDelta');
        if (ant > 0) {
          var pc = Math.round((ventas - ant) / ant * 100);
          dl.textContent = (pc >= 0 ? '+' : '') + pc + '% vs ' + PER[period];
          dl.style.color = pc >= 0 ? '' : 'var(--rp-warn)';
        } else {
          dl.textContent = 'Sin datos del per\u00edodo anterior';
          dl.style.color = 'var(--rp-mut)';
        }
        g('rpProfit').textContent = cup(gan);
        g('rpMargin').textContent = 'Margen ' + (ventas > 0 ? fmt(gan / ventas * 100, 1) : '0') + '%';
        g('rpSecTotal').textContent = cup(ventas);
        g('rpTickets').textContent = tk + (tk === 1 ? ' venta' : ' ventas');

        // ventas por sección
        var secs = D.secciones || [], st = 0;
        secs.forEach(function (s) { st += num(s.monto); });
        g('rpSecBars').innerHTML = secs.length ? secs.map(function (s, i) {
          var p = st > 0 ? Math.round(num(s.monto) / st * 100) : 0;
          return '<div class="rp-bar"><div class="rp-meta"><b>' + esc(s.nombre) + '</b><span>' +
            cup(num(s.monto)) + ' (' + p + '%)</span></div><div class="rp-track"><div class="rp-fill ' +
            COL[i % COL.length] + '" style="width:' + p + '%"></div></div></div>';
        }).join('') : vacio('Sin ventas en este per\u00edodo.');

        // métodos de cobro (lo realmente cobrado)
        var pg = {};
        (D.pagos || []).forEach(function (p) { pg[p.metodo] = num(p.monto_cup); });
        g('rpPay').innerHTML = [
          ['Efectivo CUP', cup(pg.efectivo || 0), ''],
          ['Transferencia', cup(pg.transferencia || 0), 't'],
          ['Divisas (USD/EUR)', cup(pg.exterior || 0), 'ok'],
          ['Venta promedio', cup(tk ? ventas / tk : 0), '']
        ].map(cell).join('');

        // más vendidos / poca salida
        var prods = (mode === 'top' ? D.top : D.poca_salida) || [];
        g('rpProd').innerHTML = prods.length ? prods.map(function (x, i) {
          var sub = esc(x.seccion || '') + ' \u00b7 ' + (num(x.qty) > 0 ? qtxt(x.qty, x.tipo_venta) : 'sin ventas');
          return '<div class="rp-row"><div class="rp-l"><div class="rp-rank ' + (mode === 'low' ? 'low' : '') + '">' +
            (i + 1) + '</div><div class="rp-name"><b>' + esc(x.nombre) + '</b><small>' + sub +
            '</small></div></div><div class="rp-r"><b>' + cup(num(x.monto)) + '</b></div></div>';
        }).join('') : vacio('Sin datos.');

        // por agotarse
        var ag = D.por_agotarse || [];
        g('rpStock').innerHTML = ag.length ? ag.map(function (x) {
          var d = num(x.dias), s = num(x.stock), rt = fmt(num(x.ritmo_dia), 1) + '/d\u00eda';
          var t = s <= 0 ? 'Agotado' : (d < 1 ? 'Hoy' : fmt(d, 1) + (d === 1 ? ' d\u00eda' : ' d\u00edas'));
          var sub = s <= 0 ? 'Sin stock \u00b7 ~' + rt : 'Quedan ' + qtxt(s, x.tipo_venta) + ' \u00b7 ~' + rt;
          return '<div class="rp-row"><div class="rp-name"><b>' + esc(x.nombre) + '</b><small>' + sub +
            '</small></div><span class="rp-pill ' + (s <= 0 || d <= 2 ? 'crit' : '') + '">' + t + '</span></div>';
        }).join('') : vacio('Nada se agota en los pr\u00f3ximos d\u00edas.');

        // margen real
        var mg = D.margen || [];
        var sinCosto = mg.length > 0 && mg.every(function (x) { return num(x.costo_unit) === 0; });
        g('rpMarg').innerHTML = (sinCosto ? vacio('Carga el costo de los productos en Inventario para ver el margen real.') : '') +
          (mg.length ? mg.map(function (x) {
            return '<div class="rp-row"><div class="rp-name"><b>' + esc(x.nombre) + '</b><small>Costo ' +
              fmt(num(x.costo_unit)) + ' \u00b7 Venta ' + fmt(num(x.precio_unit)) + ' CUP</small></div>' +
              '<div class="rp-r"><b class="ok">' + fmt(num(x.margen_pct), 1) + '% margen</b><small>+' +
              cup(num(x.ganancia)) + '</small></div></div>';
          }).join('') : vacio('Sin ventas en este per\u00edodo.'));

        // almacén
        var al = D.almacen || [], ti = 0, tg = 0;
        al.forEach(function (a) { ti += num(a.invertido); tg += num(a.ganancia); });
        g('rpInv').innerHTML = al.map(function (a, i) {
          return cell([esc(a.nombre), cup(num(a.invertido)), i % 2 ? 't' : '']);
        }).join('') + cell(['Total invertido', cup(ti), 'g']);
        g('rpInvProfit').innerHTML = al.map(function (a, i) {
          return cell([esc(a.nombre), '+' + cup(num(a.ganancia)), i % 2 ? 't' : '']);
        }).join('') + cell(['Total ganancia', '+' + cup(tg), 'ok']);

        // ventas por administrador
        var ad = D.admins || [], at = 0;
        ad.forEach(function (a) { at += num(a.monto); });
        g('rpAdmin').innerHTML = ad.length ? ad.map(function (a) {
          var nv = num(a.ventas), p = at > 0 ? Math.round(num(a.monto) / at * 100) : 0;
          return '<div class="rp-row"><div class="rp-l"><div class="rp-rank">' +
            esc(String(a.nombre || '?').charAt(0).toUpperCase()) + '</div><div class="rp-name"><b>' + esc(a.nombre) +
            '</b><small>' + nv + (nv === 1 ? ' venta' : ' ventas') + '</small></div></div>' +
            '<div class="rp-r"><b>' + cup(num(a.monto)) + '</b><small>' + p + '% del total</small></div></div>';
        }).join('') : vacio('Sin ventas en este per\u00edodo.');

        // deudores más morosos
        var mo = D.morosos || [];
        g('rpMorTotal').textContent = D.deuda_total != null ? cup(num(D.deuda_total)) : '';
        g('rpMor').innerHTML = mo.length ? mo.map(function (m, i) {
          var d = Math.round(num(m.dias)), nd = num(m.deudas);
          return '<div class="rp-row"><div class="rp-l"><div class="rp-rank low">' + (i + 1) +
            '</div><div class="rp-name"><b>' + esc(m.nombre) + '</b><small>' + nd + (nd === 1 ? ' deuda' : ' deudas') +
            ' \u00b7 la m\u00e1s antigua hace ' + d + (d === 1 ? ' d\u00eda' : ' d\u00edas') + '</small></div></div>' +
            '<div class="rp-r"><b>' + cup(num(m.saldo)) + '</b><span class="rp-pill ' +
            (d >= 30 ? 'crit' : (d >= 15 ? '' : 'soft')) + '">' + (d < 1 ? 'Hoy' : d + ' d') + '</span></div></div>';
        }).join('') : vacio('Sin deudas pendientes.');
      };

      var cargar = function () {
        var my = ++seq;
        root.classList.add('rp-load');
        window.CFRCargar(period, function (ok, err, json) {
          if (my !== seq) { return; }
          root.classList.remove('rp-load');
          if (!ok) { aviso(err); return; }
          var o = null;
          try { o = JSON.parse(json); } catch (e) { o = null; }
          if (!o || !o.kpis) { aviso('Respuesta inesperada del servidor.'); return; }
          D = o;
          render();
        });
      };

      var marcar = function (cont, b) {
        var bs = g(cont).querySelectorAll('button');
        for (var i = 0; i < bs.length; i++) { bs[i].classList.toggle('on', bs[i] === b); }
      };

      root.addEventListener('click', function (e) {
        var t = e.target;
        if (!t || !t.closest) { return; }
        var b = t.closest('button');
        if (!b) { return; }
        var pid = b.parentNode ? b.parentNode.id : '';
        if (b.id === 'rpBack') {
          if (window.history.length > 1) { window.history.back(); }
          else { window.location.hash = '/vender'; }
        }
        else if (pid === 'rpSeg') { period = b.getAttribute('data-p'); marcar('rpSeg', b); cargar(); }
        else if (pid === 'rpTabs') { mode = b.getAttribute('data-m'); marcar('rpTabs', b); render(); }
      });

      var red = function () {
        if (!root.isConnected) {
          window.removeEventListener('online', red);
          window.removeEventListener('offline', red);
          return;
        }
        g('rpNet').textContent = navigator.onLine ? 'En l\u00ednea' : 'Sin conexi\u00f3n';
        g('rpNet').classList.toggle('rp-off', !navigator.onLine);
      };
      window.addEventListener('online', red);
      window.addEventListener('offline', red);
      red();

      cargar();
    })();
  end;
end;

procedure TForm12.WebFormCreate(Sender: TObject);
begin
  TNavegacion.Registrar(Self);
  TShell.Actual := Self;
  TShell.Activar('mas');         // marca "Más" en el menú inferior
  PonerPuentes;
  InstalarReportes;
end;

end.
