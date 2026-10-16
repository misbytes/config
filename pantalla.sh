#!/usr/bin/env bash
# =============================================================================
# pantallas.sh - Selector de modo de pantallas para i3wm (usa xrandr)
#
# Modos:
#   1) Espejar
#   2) Extender (monitor a la derecha de la notebook)
#   3) Solo notebook
#   4) Solo monitor externo
#
# Ante cualquier falla, interrupción o si no se elige nada, el script vuelve a
# la configuración segura: SOLO la pantalla de la notebook como principal.
# =============================================================================

# ---------- Configuración (ajustá si tus salidas se llaman distinto) ---------
LAPTOP="eDP-1"
EXTERNO="HDMI-1"
LAPTOP_RES="1366x768"
EXTERNO_RES="1920x1080"
TIMEOUT=30            # segundos para elegir una opción antes de ir al default

# ---------- Utilidades de aviso ----------------------------------------------
aviso() {
    echo "[$(date +%H:%M:%S)] $*"
    command -v notify-send >/dev/null 2>&1 && notify-send -t 3000 "Pantallas" "$*" 2>/dev/null || true
}

error() {
    echo "[$(date +%H:%M:%S)] ERROR: $*" >&2
    command -v notify-send >/dev/null 2>&1 && notify-send -u critical -t 5000 "Pantallas - ERROR" "$*" 2>/dev/null || true
}

# ---------- Chequeos ---------------------------------------------------------
salida_conectada() {
    xrandr --query | grep -q "^$1 connected"
}

tiene_modo() {   # $1 = salida, $2 = resolución
    xrandr --query | awk -v o="$1" -v r="$2" '
        $1 == o { f = 1; next }
        /^[^ ]/ { f = 0 }
        f && $1 == r { ok = 1 }
        END { exit !ok }'
}

verificar_requisitos() {
    if ! command -v xrandr >/dev/null 2>&1; then
        error "xrandr no está instalado (sudo apt install x11-xserver-utils)."
        return 1
    fi
    [ -z "$DISPLAY" ] && export DISPLAY=:0
    if ! xrandr --query >/dev/null 2>&1; then
        error "No se pudo consultar el servidor gráfico (DISPLAY=$DISPLAY)."
        return 1
    fi
    if ! salida_conectada "$LAPTOP"; then
        error "No se detecta la pantalla de la notebook ($LAPTOP). Revisá el nombre con: xrandr"
        return 1
    fi
    return 0
}

requiere_externo() {
    if ! salida_conectada "$EXTERNO"; then
        error "El monitor externo ($EXTERNO) no está conectado."
        return 1
    fi
    if ! tiene_modo "$EXTERNO" "$EXTERNO_RES"; then
        error "El monitor externo no ofrece la resolución $EXTERNO_RES."
        return 1
    fi
    return 0
}

# ---------- Modos ------------------------------------------------------------
solo_notebook() {
    aviso "Configurando: solo notebook ($LAPTOP a $LAPTOP_RES)..."
    xrandr \
        --output "$LAPTOP" --mode "$LAPTOP_RES" --scale 1x1 --pos 0x0 --rotate normal --primary \
        --output "$EXTERNO" --off
}

solo_externo() {
    requiere_externo || return 1
    aviso "Configurando: solo monitor externo ($EXTERNO a $EXTERNO_RES)..."
    xrandr \
        --output "$EXTERNO" --mode "$EXTERNO_RES" --scale 1x1 --pos 0x0 --rotate normal --primary \
        --output "$LAPTOP" --off
}

extender() {
    requiere_externo || return 1
    aviso "Configurando: extender ($LAPTOP a $LAPTOP_RES + $EXTERNO a $EXTERNO_RES a la derecha)..."
    xrandr \
        --output "$LAPTOP" --mode "$LAPTOP_RES" --scale 1x1 --pos 0x0 --rotate normal --primary \
        --output "$EXTERNO" --mode "$EXTERNO_RES" --scale 1x1 --rotate normal --right-of "$LAPTOP"
}

espejar() {
    requiere_externo || return 1
    # El monitor se usa a su resolución nativa y la notebook (más chica) escala
    # su imagen para mostrar el mismo escritorio de 1920x1080.
    aviso "Configurando: espejar (escritorio de $EXTERNO_RES; notebook escalada desde $LAPTOP_RES)..."
    xrandr \
        --output "$EXTERNO" --mode "$EXTERNO_RES" --scale 1x1 --pos 0x0 --rotate normal \
        --output "$LAPTOP" --mode "$LAPTOP_RES" --scale-from "$EXTERNO_RES" --pos 0x0 --rotate normal --primary
}

# ---------- Fallback (configuración segura) ----------------------------------
fallback() {
    aviso "Volviendo a la configuración por defecto: solo notebook..."
    if solo_notebook; then
        aviso "Listo: quedó activa solo la pantalla de la notebook."
        return 0
    fi
    error "Falló el ajuste normal. Intentando modo automático de emergencia..."
    if xrandr --output "$LAPTOP" --auto --scale 1x1 --primary --output "$EXTERNO" --off; then
        aviso "Listo (modo automático): solo notebook."
        return 0
    fi
    error "No se pudo restaurar la pantalla de la notebook. Probá manualmente: xrandr --auto"
    return 1
}

# Si se interrumpe durante la selección/aplicación, volver al default.
trap 'echo; error "Interrumpido por el usuario."; fallback; exit 1' INT TERM

# ---------- Menú -------------------------------------------------------------
mostrar_menu() {
    echo
    echo "=========== Configuración de pantallas ==========="
    echo "  1) Espejar pantallas"
    echo "  2) Extender pantallas"
    echo "  3) Solo notebook ($LAPTOP)"
    echo "  4) Solo monitor externo ($EXTERNO)"
    echo "  0) Cancelar (deja solo la notebook)"
    echo "=================================================="
    echo "Sin respuesta en ${TIMEOUT}s se aplica: solo notebook."
}

aplicar_opcion() {
    case "$1" in
        1) espejar ;;
        2) extender ;;
        3) solo_notebook ;;
        4) solo_externo ;;
        *) return 99 ;;
    esac
}

# ---------- Programa principal -----------------------------------------------
if ! verificar_requisitos; then
    # Sin xrandr/DISPLAY no hay mucho que restaurar, pero se intenta igual.
    command -v xrandr >/dev/null 2>&1 && fallback
    exit 1
fi

while true; do
    mostrar_menu
    opcion=""
    if ! read -r -t "$TIMEOUT" -p "Elegí una opción [0-4]: " opcion; then
        echo
        aviso "No se eligió ninguna opción a tiempo."
        fallback
        opcion="0"
    else
        case "$opcion" in
            1|2|3|4)
                aplicar_opcion "$opcion"
                rc=$?
                if [ "$rc" -eq 0 ]; then
                    aviso "Configuración aplicada correctamente."
                else
                    error "No se pudo aplicar la opción $opcion (código $rc)."
                    fallback
                fi
                ;;
            ""|0)
                aviso "Sin selección: se aplica la configuración por defecto."
                fallback
                ;;
            *)
                error "Opción inválida: '$opcion'."
                fallback
                ;;
        esac
    fi

    # Estado actual
    echo
    aviso "Estado actual de las salidas activas:"
    xrandr --query | grep " connected" | sed 's/^/    /'

    # Finalización manual: la configuración queda aplicada al salir.
    trap 'echo; aviso "Script finalizado. La configuración actual queda aplicada."; exit 0' INT TERM
    echo
    read -r -p "Enter = finalizar (la configuración queda aplicada) | m = volver al menú: " fin
    case "$fin" in
        m|M)
            trap 'echo; error "Interrumpido por el usuario."; fallback; exit 1' INT TERM
            continue
            ;;
        *)
            aviso "Script finalizado. La configuración actual queda aplicada."
            exit 0
            ;;
    esac
done
