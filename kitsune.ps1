# Kitsune: Kurama de nueve colas siempre visible. Cada cola es una sesion de Claude Code;
# la punta es gris (en reposo), verde (trabajando) o roja (te espera).
# Lee los archivos que escribe estado.mjs. Correr con: powershell -STA -File kitsune.ps1
# Estilo chibi de Kurama. Se dibuja en un lienzo de 200x190 que el Viewbox escala.
# -Captura <png>: guarda una imagen del zorro a los 3 s (para revisar el dibujo).
param([string]$Carpeta = (Join-Path $env:USERPROFILE '.claude\kitsune\estado'), [string]$Captura)

$creado = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\kitsune-claude', [ref]$creado)
if (-not $creado) { exit }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$base = Split-Path $Carpeta -Parent
$archivoPosicion = Join-Path $base 'posicion.json'
New-Item -ItemType Directory -Force -Path $Carpeta | Out-Null

function Pincel($hex) { [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }
$naranja  = Pincel '#F7941D'
$sombra   = Pincel '#D9700F'
$linea    = Pincel '#1E1E1E'
$marron   = Pincel '#3B2416'
$colores  = @{ gris = '#B5B5B5'; verde = '#2EB82E'; rojo = '#E00000' }
$textos   = @{ gris = 'en reposo'; verde = 'trabajando'; rojo = 'te espera' }
$textoDecision = "espera tu decisi$([char]0x00F3)n"
function Texto-Estado($s) {
    $estado = [string]$s.estado
    if ($estado -eq 'rojo' -and $s.decision) { return $textoDecision }
    if ($textos.ContainsKey($estado)) { $textos[$estado] } else { $textos.gris }
}
$utf8     = New-Object System.Text.UTF8Encoding($false)

# --- Ventana -------------------------------------------------------------
$ventana = New-Object Windows.Window
$ventana.WindowStyle = 'None'
$ventana.AllowsTransparency = $true
$ventana.Background = $null
$ventana.Topmost = $true
$ventana.ShowInTaskbar = $false
$ventana.ResizeMode = 'NoResize'
$ventana.Width = 180; $ventana.Height = 171
$ventana.Left = [Windows.SystemParameters]::WorkArea.Right - 200
$ventana.Top = [Windows.SystemParameters]::WorkArea.Bottom - 190
try {
    $p = Get-Content $archivoPosicion -Raw -ErrorAction Stop | ConvertFrom-Json
    $ventana.Left = $p.left; $ventana.Top = $p.top
} catch { }

$lienzo = New-Object Windows.Controls.Canvas
$lienzo.Width = 200; $lienzo.Height = 190
$temblor = New-Object Windows.Media.TranslateTransform
$lienzo.RenderTransform = $temblor
$vista = New-Object Windows.Controls.Viewbox
$vista.Child = $lienzo
$ventana.Content = $vista

function Trazo($datos, $relleno, $grosor = 1.8, $borde = $linea) {
    $p = New-Object Windows.Shapes.Path
    $p.Data = [Windows.Media.Geometry]::Parse($datos)
    $p.Fill = $relleno
    if ($borde) { $p.Stroke = $borde; $p.StrokeThickness = $grosor; $p.StrokeLineJoin = 'Round' }
    $p
}
function Espejo($datos) {
    # Refleja un trazo sobre el eje vertical x = 100.
    [regex]::Replace($datos, '(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)', { param($m) "$(200 - [double]$m.Groups[1].Value),$($m.Groups[2].Value)" })
}

# Las colas van primero para quedar detras del cuerpo.
$capaColas = New-Object Windows.Controls.Canvas
[void]$lienzo.Children.Add($capaColas)

# Todo lo que no es cola: se arrastra con el mouse.
$zorro = New-Object Windows.Controls.Canvas
$zorro.Cursor = 'SizeAll'
[void]$lienzo.Children.Add($zorro)
function Poner($figura) { [void]$zorro.Children.Add($figura); $figura }

# Cuerpo sentado: ancas, torso, patas.
[void](Poner (Trazo 'M 60,178 C 52,160 62,142 80,146 C 86,160 84,174 78,180 Z' $naranja))
[void](Poner (Trazo (Espejo 'M 60,178 C 52,160 62,142 80,146 C 86,160 84,174 78,180 Z') $naranja))
[void](Poner (Trazo 'M 84,118 C 78,140 76,165 80,180 L 120,180 C 124,165 122,140 116,118 Z' $naranja))
[void](Poner (Trazo 'M 93,138 L 91,176' $null 1.6))
[void](Poner (Trazo 'M 107,138 L 109,176' $null 1.6))
[void](Poner (Trazo 'M 80,182 C 80,174 92,172 94,178 C 95,183 81,185 80,182 Z' $naranja))
[void](Poner (Trazo (Espejo 'M 80,182 C 80,174 92,172 94,178 C 95,183 81,185 80,182 Z') $naranja))

# Orejas (dentro de un grupo que baja cuando el zorro esta tranquilo).
$orejas = New-Object Windows.Controls.Canvas
$bajarOrejas = New-Object Windows.Media.TranslateTransform
$orejas.RenderTransform = $bajarOrejas
[void]$zorro.Children.Add($orejas)
foreach ($d in @('M 66,86 C 54,62 50,40 52,18 C 70,30 86,48 96,70 Z')) {
    [void]$orejas.Children.Add((Trazo $d $naranja))
    [void]$orejas.Children.Add((Trazo (Espejo $d) $naranja))
}
foreach ($d in @('M 70,78 C 62,60 59,46 60,30 C 72,42 80,54 86,68 Z')) {
    [void]$orejas.Children.Add((Trazo $d $marron 0))
    [void]$orejas.Children.Add((Trazo (Espejo $d) $marron 0))
}

# Cabeza ancha con mechones en las mejillas.
[void](Poner (Trazo 'M 58,96 C 58,64 142,64 142,96 L 154,104 L 141,107 L 149,115 L 132,117 C 120,130 80,130 68,117 L 51,115 L 59,107 L 46,104 Z' $naranja))

# Marca oscura de los ojos, con el ceno de la referencia.
$marca = 'M 61,104 C 57,94 60,86 66,82 C 75,87 88,93 97,105 C 88,97 77,92 67,94 C 64,97 62,100 61,104 Z'
[void](Poner (Trazo $marca $marron 0))
[void](Poner (Trazo (Espejo $marca) $marron 0))

# Ojos abiertos (alerta) y cerrados (tranquilo).
$abiertos = New-Object Windows.Controls.Canvas
[void]$zorro.Children.Add($abiertos)
function Circulo($cx, $cy, $r, $relleno, $borde, $grosor) {
    $e = New-Object Windows.Shapes.Ellipse
    $e.Width = 2 * $r; $e.Height = 2 * $r; $e.Fill = Pincel $relleno
    if ($borde) { $e.Stroke = Pincel $borde; $e.StrokeThickness = $grosor }
    [Windows.Controls.Canvas]::SetLeft($e, $cx - $r)
    [Windows.Controls.Canvas]::SetTop($e, $cy - $r)
    $e
}
# Ojo almendrado con el parpado grueso bajando hacia la nariz (ceno) y brillo arriba a la derecha.
# Se dibuja el izquierdo y el derecho sale reflejado; el brillo no se refleja (misma luz).
$formaOjo  = 'M 67,95 C 74,89 87,93 96,105 C 87,109 75,107 67,95 Z'
$parpadoSup = 'M 63,91 C 72,87 87,92 97,106'
$parpadoInf = 'M 68,96 C 75,106 87,109 96,105'
$ceja      = 'M 92,83 Q 96,88 95,94'
foreach ($reflejar in @($false, $true)) {
    $ver = { param($d) if ($reflejar) { Espejo $d } else { $d } }
    $ojo = & $ver $formaOjo
    [void]$abiertos.Children.Add((Trazo $ojo (Pincel '#FFF6E0') 0))
    $iris = New-Object Windows.Controls.Canvas
    $iris.Clip = [Windows.Media.Geometry]::Parse($ojo)
    $cx = if ($reflejar) { 116 } else { 84 }
    [void]$iris.Children.Add((Circulo $cx 100.5 7.5 '#D01010' '#6A0000' 1.4))
    [void]$iris.Children.Add((Circulo $cx 100.5 3.5 '#1E1E1E' $null 0))
    [void]$iris.Children.Add((Circulo ($cx + 3) 97.5 2 '#FFFFFF' $null 0))
    [void]$abiertos.Children.Add($iris)
    [void]$abiertos.Children.Add((Trazo (& $ver $parpadoSup) $null 3.6))
    [void]$abiertos.Children.Add((Trazo (& $ver $parpadoInf) $null 1.2))
    [void]$abiertos.Children.Add((Trazo (& $ver $ceja) $null 1.4))
}

# Cerrados: arcos sonrientes, con el lado de la nariz mas bajo para conservar el ceno.
$cerrados = New-Object Windows.Controls.Canvas
[void]$zorro.Children.Add($cerrados)
[void]$cerrados.Children.Add((Trazo 'M 73,99 Q 80,93 92,104' $null 2.4))
[void]$cerrados.Children.Add((Trazo (Espejo 'M 73,99 Q 80,93 92,104') $null 2.4))

# Dormido (todas las colas grises): ojos cerrados caidos, sin ceno.
$dormidos = New-Object Windows.Controls.Canvas
[void]$zorro.Children.Add($dormidos)
[void]$dormidos.Children.Add((Trazo 'M 73,99 Q 82,106 91,100' $null 2.4))
[void]$dormidos.Children.Add((Trazo (Espejo 'M 73,99 Q 82,106 91,100') $null 2.4))

# Nariz, boca con las comisuras hacia arriba y bigotes.
[void](Poner (Trazo 'M 96,108 C 96,105 104,105 104,108 C 104,111 96,111 96,108 Z' $linea 0))
[void](Poner (Trazo 'M 87,111 Q 90,116 94,115 Q 97,118 100,114 Q 103,118 106,115 Q 110,116 113,111' $null 1.6))
foreach ($d in @('M 76,110 L 60,107', 'M 76,113 L 61,115')) {
    [void](Poner (Trazo $d $null 1))
    [void](Poner (Trazo (Espejo $d) $null 1))
}

$alerta = New-Object Windows.Controls.TextBlock
$alerta.Text = '!'; $alerta.FontSize = 34; $alerta.FontWeight = 'Black'
$alerta.Foreground = Pincel '#E00000'; $alerta.Visibility = 'Hidden'
[Windows.Controls.Canvas]::SetLeft($alerta, 158); [Windows.Controls.Canvas]::SetTop($alerta, 14)
[void]$lienzo.Children.Add($alerta)

$zzz = New-Object Windows.Controls.TextBlock
$zzz.Inlines.Add((New-Object Windows.Documents.Run('z')))
$grande = New-Object Windows.Documents.Run('Z'); $grande.FontSize = 22
$zzz.Inlines.Add($grande)
$zzz.Inlines.Add((New-Object Windows.Documents.Run('z')))
$zzz.FontSize = 15; $zzz.FontWeight = 'Bold'; $zzz.Foreground = Pincel '#4A5A7A'
$flotar = New-Object Windows.Media.TranslateTransform
$zzz.RenderTransform = $flotar
[Windows.Controls.Canvas]::SetLeft($zzz, 158); [Windows.Controls.Canvas]::SetTop($zzz, 4)
[void]$lienzo.Children.Add($zzz)

$extra = New-Object Windows.Controls.TextBlock
$extra.FontSize = 13; $extra.FontWeight = 'Bold'; $extra.Foreground = $linea
[Windows.Controls.Canvas]::SetLeft($extra, 172); [Windows.Controls.Canvas]::SetTop($extra, 168)
[void]$lienzo.Children.Add($extra)

# --- Interaccion ---------------------------------------------------------
Add-Type -Namespace Kitsune -Name Win -UsingNamespace System.Text, System.Diagnostics -MemberDefinition @'
delegate bool Visitar(IntPtr h, IntPtr l);
[DllImport("user32.dll")] static extern bool EnumWindows(Visitar v, IntPtr l);
[DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder t, int n);
[DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int modo);
[DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
// Trae al frente la ventana de VS Code cuyo titulo contiene el nombre (o la primera si viene vacio).
public static bool Traer(string nombre) {
    IntPtr elegida = IntPtr.Zero;
    EnumWindows((h, l) => {
        if (!IsWindowVisible(h)) return true;
        var t = new StringBuilder(512); GetWindowText(h, t, 512);
        string titulo = t.ToString();
        if (!titulo.EndsWith("Visual Studio Code")) return true;
        uint pid; GetWindowThreadProcessId(h, out pid);
        try { if (Process.GetProcessById((int)pid).ProcessName != "Code") return true; } catch { return true; }
        if (string.IsNullOrEmpty(nombre) || titulo.Contains(nombre)) { elegida = h; return false; }
        return true;
    }, IntPtr.Zero);
    if (elegida == IntPtr.Zero) return false;
    if (IsIconic(elegida)) ShowWindow(elegida, 9);
    return SetForegroundWindow(elegida);
}
'@

# Lleva a la terminal de VS Code donde corre la sesion; no cambia su color.
function Ir-A($s) {
    if (-not $s.shell) {
        $msg = "Todav$([char]0xED)a no s$([char]0xE9) en qu$([char]0xE9) terminal est$([char]0xE1) $($s.proyecto). " +
               "Escr$([char]0xED)bele algo una vez y vuelve a intentarlo."
        [void][Windows.MessageBox]::Show($msg, 'Kitsune')
        return
    }
    $nombreVentana = ''
    try { $nombreVentana = (Get-Content (Join-Path $base "terminales\$($s.shell).json") -Raw -Encoding UTF8 | ConvertFrom-Json).ventana } catch { }
    [void][Kitsune.Win]::Traer($nombreVentana)
    $pedido = @{ shell = [int]$s.shell; ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() } | ConvertTo-Json -Compress
    [IO.File]::WriteAllText((Join-Path $base 'enfocar.json'), $pedido, $utf8)
}

# Lista de sesiones, primero las que te esperan.
function Mostrar-Lista {
    $lista = New-Object Windows.Controls.ContextMenu
    $orden = @{ rojo = 0; verde = 1; gris = 2 }
    $sesiones = @($script:sesiones | Sort-Object { $orden[[string]$_.estado] }, inicio)
    if (-not $sesiones.Count) {
        $vacio = New-Object Windows.Controls.MenuItem
        $vacio.Header = 'No hay sesiones abiertas'; $vacio.IsEnabled = $false
        [void]$lista.Items.Add($vacio)
    }
    foreach ($s in $sesiones) {
        $estado = [string]$s.estado
        if (-not $colores.ContainsKey($estado)) { $estado = 'gris' }
        $fila = New-Object Windows.Controls.StackPanel
        $fila.Orientation = 'Horizontal'
        $punto = New-Object Windows.Shapes.Ellipse
        $punto.Width = 10; $punto.Height = 10; $punto.Margin = '0,0,8,0'
        $punto.Fill = Pincel $colores[$estado]
        $nombre = New-Object Windows.Controls.TextBlock
        $nombre.Text = "$($s.proyecto)  -  $(Texto-Estado $s)"
        if ($estado -eq 'rojo') { $nombre.FontWeight = 'Bold' }
        [void]$fila.Children.Add($punto); [void]$fila.Children.Add($nombre)
        $item = New-Object Windows.Controls.MenuItem
        $item.Header = $fila
        $item.Tag = $s
        $item.Add_Click({ param($o) Ir-A $o.Tag })
        [void]$lista.Items.Add($item)
    }
    $lista.PlacementTarget = $zorro
    $lista.Placement = 'Bottom'
    $lista.IsOpen = $true
}

# Arrastrar mueve al zorro; un clic sin moverlo abre la lista.
$zorro.Add_MouseLeftButtonDown({
    $antes = "$($ventana.Left),$($ventana.Top)"
    $ventana.DragMove()
    if ("$($ventana.Left),$($ventana.Top)" -eq $antes) { Mostrar-Lista }
})
$ventana.Add_LocationChanged({
    try { [IO.File]::WriteAllText($archivoPosicion, (@{ left = $ventana.Left; top = $ventana.Top } | ConvertTo-Json), $utf8) } catch { }
})
$menu = New-Object Windows.Controls.ContextMenu
$cerrar = New-Object Windows.Controls.MenuItem
$cerrar.Header = 'Cerrar kitsune'
$cerrar.Add_Click({ $ventana.Close() })
[void]$menu.Items.Add($cerrar)
$zorro.ContextMenu = $menu

# Nombre de la sesion al pasar el mouse por una cola. Es una burbuja propia y no un ToolTip:
# el ToolTip de WPF se cerraba enseguida en esta ventana transparente, siempre encima e inactiva.
$nombreBurbuja = New-Object Windows.Controls.TextBlock
$nombreBurbuja.Foreground = Pincel '#FFFFFF'; $nombreBurbuja.FontSize = 12
$fondoBurbuja = New-Object Windows.Controls.Border
$fondoBurbuja.Background = $linea; $fondoBurbuja.CornerRadius = 4; $fondoBurbuja.Padding = '7,3'
$fondoBurbuja.Child = $nombreBurbuja
$burbuja = New-Object Windows.Controls.Primitives.Popup
$burbuja.AllowsTransparency = $true
$burbuja.Placement = 'Mouse'
$burbuja.PlacementTarget = $lienzo
$burbuja.Child = $fondoBurbuja
$mostrarNombre = {
    param($origen)
    $s = $origen.Tag
    $nombreBurbuja.Text = "$($s.proyecto) - $(Texto-Estado $s)"
    $burbuja.IsOpen = $false
    $burbuja.IsOpen = $true
}
$ocultarNombre = { $burbuja.IsOpen = $false }

# Clic en una cola: lleva a esa sesion sin cambiarle el color.
$irDesdeCola = {
    param($origen, $evento)
    Ir-A $origen.Tag
    $evento.Handled = $true
}

# --- Colas ---------------------------------------------------------------
# Llama curva con la punta hacia la izquierda; las de la derecha se reflejan.
$formaCola = 'M -13,0 C -24,-40 -4,-68 -20,-112 C 4,-96 22,-64 13,0 Z'
$sombraCola = 'M 5,-5 C 10,-36 2,-60 -8,-74'
# Las colas salen de los costados hacia el centro, para que las primeras no queden tras la cabeza;
# las ultimas asoman por el hueco entre las orejas.
$angulos = @(-62, 62, -44, 44, -26, 26, -8, 8, 0)

function Relleno-Cola($estado) {
    # Punta del color del estado, con corte nitido sobre el naranja.
    $g = New-Object Windows.Media.LinearGradientBrush
    $g.StartPoint = '0.5,0'; $g.EndPoint = '0.5,1'
    $c = [Windows.Media.ColorConverter]::ConvertFromString($colores[$estado])
    $o = [Windows.Media.ColorConverter]::ConvertFromString('#F7941D')
    foreach ($par in @(@($c, 0), @($c, 0.3), @($o, 0.3), @($o, 1))) {
        $g.GradientStops.Add((New-Object Windows.Media.GradientStop($par[0], $par[1])))
    }
    $g
}
$script:parpadean = @()

function Dibujar-Colas($sesiones) {
    $capaColas.Children.Clear()
    $script:parpadean = @()
    $visibles = @($sesiones | Select-Object -First 9)
    for ($i = 0; $i -lt $visibles.Count; $i++) {
        $s = $visibles[$i]
        $estado = [string]$s.estado
        if (-not $colores.ContainsKey($estado)) { $estado = 'gris' }
        $cola = New-Object Windows.Controls.Canvas
        $cuerpoCola = Trazo $formaCola (Relleno-Cola $estado)
        [void]$cola.Children.Add($cuerpoCola)
        [void]$cola.Children.Add((Trazo $sombraCola $null 3 $sombra))
        $giro = New-Object Windows.Media.TransformGroup
        $espejo = if ($angulos[$i] -gt 0) { -1 } else { 1 }
        $largo = if ([math]::Abs($angulos[$i]) -lt 15) { 1.25 } else { 1 }   # las del centro asoman sobre las orejas
        $giro.Children.Add((New-Object Windows.Media.ScaleTransform($espejo, $largo)))
        $giro.Children.Add((New-Object Windows.Media.RotateTransform($angulos[$i])))
        $giro.Children.Add((New-Object Windows.Media.TranslateTransform(100, 150)))
        $cola.RenderTransform = $giro
        $cola.Add_MouseEnter($mostrarNombre)
        $cola.Add_MouseLeave($ocultarNombre)
        $cola.Tag = $s
        $cola.Cursor = 'Hand'
        $cola.Background = $null
        $cola.Add_MouseLeftButtonDown($irDesdeCola)
        [void]$capaColas.Children.Add($cola)
        if ($estado -eq 'rojo') { $script:parpadean += , $cuerpoCola.Fill }
    }
    $extra.Text = if ($sesiones.Count -gt 9) { "+$($sesiones.Count - 9)" } else { '' }
}

# --- Estado --------------------------------------------------------------
$script:firma = ''
$script:hayRojas = $false

function Leer-Sesiones {
    $limite = [DateTimeOffset]::UtcNow.AddHours(-12).ToUnixTimeMilliseconds()
    $lista = foreach ($f in Get-ChildItem $Carpeta -Filter *.json -ErrorAction SilentlyContinue) {
        try {
            $s = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            # Sesion muerta sin SessionEnd (terminal cerrada a la fuerza) o sin cambios en 12 h.
            $muerta = $s.claude -and -not (Get-Process -Id $s.claude -ErrorAction SilentlyContinue)
            if ($muerta -or $s.ts -lt $limite) { Remove-Item $f.FullName -ErrorAction SilentlyContinue; continue }
            $s | Add-Member -NotePropertyName ruta -NotePropertyValue $f.FullName -PassThru
        } catch { }
    }
    @($lista | Sort-Object inicio)
}

# Ir a la terminal de una sesion roja es haberla atendido: pasa a gris. Solo cuenta un foco
# posterior a cuando se puso roja (foco.json lo escribe la extension kitsune-puente).
function Marcar-Vistas($sesiones) {
    try { $foco = Get-Content (Join-Path $base 'foco.json') -Raw -ErrorAction Stop | ConvertFrom-Json } catch { return }
    if (-not $foco.shell) { return }
    foreach ($s in $sesiones) {
        # Una decision pendiente no se apaga por mirarla: solo contestando.
        if ($s.estado -eq 'rojo' -and -not $s.decision -and $s.shell -eq $foco.shell -and $foco.ts -gt $s.ts) {
            $s.estado = 'gris'
            $datos = $s | Select-Object * -ExcludeProperty ruta | ConvertTo-Json -Compress
            try { [IO.File]::WriteAllText($s.ruta, $datos, $utf8) } catch { }
        }
    }
}

function Poner-Modo($modo) {
    # alerta: hay rojas (ojos abiertos, signo, orejas arriba); tranquilo: alguna verde (ojos cerrados
    # sonrientes); dormido: todas grises o ninguna sesion (ojos caidos, Zzz, orejas mas bajas).
    $script:hayRojas = $modo -eq 'alerta'
    $script:duerme = $modo -eq 'dormido'
    $ver = { param($si) if ($si) { 'Visible' } else { 'Hidden' } }
    $alerta.Visibility   = & $ver ($modo -eq 'alerta')
    $abiertos.Visibility = & $ver ($modo -eq 'alerta')
    $cerrados.Visibility = & $ver ($modo -eq 'tranquilo')
    $dormidos.Visibility = & $ver ($modo -eq 'dormido')
    $zzz.Visibility      = & $ver ($modo -eq 'dormido')
    $bajarOrejas.Y = switch ($modo) { 'alerta' { 0 } 'tranquilo' { 7 } default { 12 } }
}
function Modo-De($sesiones) {
    if ($sesiones | Where-Object estado -eq 'rojo') { 'alerta' }
    elseif ($sesiones | Where-Object estado -eq 'verde') { 'tranquilo' }
    else { 'dormido' }
}
Poner-Modo 'dormido'

function Encender-Puntas($encendida) {
    # Las dos primeras paradas del degradado son la punta: roja o del color de la cola.
    $color = [Windows.Media.ColorConverter]::ConvertFromString($(if ($encendida) { $colores.rojo } else { '#F7941D' }))
    foreach ($relleno in $script:parpadean) {
        $relleno.GradientStops[0].Color = $color
        $relleno.GradientStops[1].Color = $color
    }
}

$script:paso = 0
$reloj = New-Object Windows.Threading.DispatcherTimer
$reloj.Interval = [TimeSpan]::FromMilliseconds(100)
$reloj.Add_Tick({
    $script:paso++
    if ($script:paso % 10 -eq 1) {
        $sesiones = Leer-Sesiones
        Marcar-Vistas $sesiones
        $script:sesiones = $sesiones
        $firma = ($sesiones | ForEach-Object { "$($_.ruta)|$($_.estado)|$($_.decision)|$($_.proyecto)" }) -join ';'
        # Con el mouse sobre las colas no se redibuja: recrearlas cerraria el tooltip.
        if ($firma -ne $script:firma -and -not $capaColas.IsMouseOver) {
            $script:firma = $firma
            Dibujar-Colas $sesiones
            Poner-Modo (Modo-De $sesiones)
        }
    }
    if ($script:hayRojas) {
        # Tiembla 0,6 s cada 3 s y las puntas rojas parpadean.
        $ciclo = $script:paso % 30
        # No tiembla con el mouse encima: moverse lo sacaria de la cola y cerraria el tooltip.
        $temblor.X = if ($ciclo -lt 6 -and -not $lienzo.IsMouseOver) { if ($ciclo % 2) { 2 } else { -2 } } else { 0 }
        Encender-Puntas (($script:paso % 10) -lt 6)
    } else {
        $temblor.X = 0
    }
    if ($script:duerme) {
        # Las Zzz suben y bajan despacio (ciclo de 4 s).
        $flotar.Y = -3 * [math]::Sin($script:paso * [math]::PI / 20)
    }
})
$reloj.Start()

if ($Captura) {
    $foto = New-Object Windows.Threading.DispatcherTimer
    $foto.Interval = [TimeSpan]::FromSeconds(3)
    $foto.Add_Tick({
        $foto.Stop()
        $temblor.X = 0
        Encender-Puntas $true
        $w = [int]$ventana.Width; $h = [int]$ventana.Height
        $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap(($w * 2), ($h * 2), 192, 192, [Windows.Media.PixelFormats]::Pbgra32)
        $fondo = New-Object Windows.Media.DrawingVisual
        $dc = $fondo.RenderOpen(); $dc.DrawRectangle((Pincel '#FFFFFF'), $null, (New-Object Windows.Rect(0, 0, $w, $h))); $dc.Close()
        $rtb.Render($fondo); $rtb.Render($vista)
        $png = New-Object Windows.Media.Imaging.PngBitmapEncoder
        $png.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $flujo = [IO.File]::Create($Captura); $png.Save($flujo); $flujo.Close()
    })
    $foto.Start()
}

[void]$ventana.ShowDialog()
$mutex.ReleaseMutex()
