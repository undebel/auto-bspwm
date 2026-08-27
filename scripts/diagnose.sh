#!/bin/sh
# Diagnose a broken bspwm session installed by auto-bspwm's setup.sh.
# Run it from a TTY (Ctrl+Alt+F3) or a terminal INSIDE the broken session:
#     sh ~/auto-bspwm/scripts/diagnose.sh
# It only reads state (no changes) and writes a report to ~/bspwm-diagnose.txt

OUT="${HOME}/bspwm-diagnose.txt"
: > "$OUT"

log() { printf '%s\n' "$*" | tee -a "$OUT"; }

section() {
	log ""
	log "==================== $* ===================="
}

run() {
	log "\$ $*"
	# shellcheck disable=SC2068
	$@ 2>&1 | tee -a "$OUT"
}

section "SISTEMA"
run cat /etc/os-release
run uname -r
run systemd-detect-virt
log "Usuario: $(id -un) (uid $(id -u))"
log "DISPLAY=${DISPLAY:-<no definido>}  XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-<no definido>}"

section "SESION GRAFICA (loginctl)"
run loginctl list-sessions --no-legend
for s in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
	log "--- sesion $s:"
	loginctl show-session "$s" -p Name -p Type -p Desktop -p State 2>&1 | tee -a "$OUT"
done

section "PAQUETES INSTALADOS"
run dpkg-query -W -f='${Package} ${Version} ${Status}\n' \
	bspwm sxhkd polybar picom kitty rofi feh i3lock suckless-tools scrot imagemagick

section "FICHEROS QUE DEBIO INSTALAR setup.sh"
for f in \
	"$HOME/.config/bspwm/bspwmrc" \
	"$HOME/.config/sxhkd/sxhkdrc" \
	"$HOME/.config/polybar/launch.sh" \
	"$HOME/.config/polybar/shapes/config.ini" \
	"$HOME/.config/picom/picom.conf" \
	"$HOME/.zshrc" \
	"$HOME/Wallpapers/archkali.png" \
	/usr/local/bin/lockscreen \
	/usr/local/bin/whichSystem.py; do
	if [ -e "$f" ]; then
		log "OK      $(ls -l "$f")"
	else
		log "FALTA   $f"
	fi
done

section "PROCESOS DE LA SESION"
for p in bspwm sxhkd polybar picom Xorg lightdm; do
	log "--- $p:"
	pgrep -a "$p" 2>&1 | tee -a "$OUT" || log "(no corre)"
done

section "LOGS DE SESION X"
for f in "$HOME/.xsession-errors" "$HOME"/.local/share/xorg/Xorg.*.log; do
	[ -f "$f" ] || continue
	log "--- ultimas 30 lineas de $f:"
	tail -n 30 "$f" | tee -a "$OUT"
done

section "PRUEBAS ACTIVAS (solo si hay DISPLAY accesible)"
DISP="${DISPLAY:-:0}"
if DISPLAY="$DISP" xset q >/dev/null 2>&1; then
	log "X accesible en $DISP"
	log "--- ¿Super mapeado a mod4?:"
	DISPLAY="$DISP" xmodmap -pm 2>&1 | tee -a "$OUT"
	log "--- estado de bspwm (bspc):"
	DISPLAY="$DISP" bspc wm -d 2>&1 | head -5 | tee -a "$OUT"
	log "--- sxhkd de prueba (3s; los errores de parseo del sxhkdrc saldrian aqui):"
	pgrep -x sxhkd >/dev/null && log "(ya hay un sxhkd corriendo, no se lanza otro)" \
		|| DISPLAY="$DISP" timeout 3 sxhkd 2>&1 | tee -a "$OUT"
else
	log "No hay X accesible desde aqui ($DISP): pruebas activas omitidas."
	log "(Ejecuta este script desde un terminal dentro de la sesion bspwm"
	log " o desde TTY con: DISPLAY=:0 sh diagnose.sh)"
fi

section "FIN"
log "Informe guardado en: $OUT"
log "Comparte ese fichero para el analisis."
