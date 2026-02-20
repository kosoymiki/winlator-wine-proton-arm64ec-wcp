# Winlator container hang: logging & triage guide

Если Winlator зависает на "Starting up...", нам нужен **строго воспроизводимый лог-пакет**.

## 1) Подготовка устройства

1. Включите Developer Options + USB debugging.
2. Подключите устройство к ПК и проверьте:

```bash
adb devices
```

## 2) Снять логи во время зависания

> Важно: сначала очистить буфер, потом воспроизвести зависание, потом сохранить логи.

```bash
adb logcat -c
adb shell rm -f /sdcard/winlator-hang-logcat.txt
adb logcat -b main,system,events,crash -v threadtime > winlator-hang-logcat.txt
```

Дальше:
1. Запустите Winlator и дождитесь зависания на "Starting up..." (30-90 сек).
2. Остановите `logcat` (`Ctrl+C`).

## 3) Снять системные дампы (обязательно)

```bash
adb shell dumpsys activity processes > dumpsys-processes.txt
adb shell dumpsys activity top > dumpsys-top.txt
adb shell dumpsys meminfo > dumpsys-meminfo.txt
adb shell cat /proc/pressure/memory > psi-memory.txt
adb shell cat /proc/pressure/cpu > psi-cpu.txt
```

Если доступно:

```bash
adb shell ls -l /data/anr/
adb shell su -c 'cp /data/anr/* /sdcard/'
adb pull /sdcard/anr_* ./anr_traces/
```

## 4) Точечный фильтр под Winlator

```bash
adb logcat -d -v threadtime | grep -Ei "winlator|wineserver|wine64|fex|hangover|ANR|Input dispatching timed out|ActivityManager|lowmemorykiller|SIGKILL|OutOfMemory"
```

## 5) Что присылать для точного root-cause

- `winlator-hang-logcat.txt`
- `dumpsys-processes.txt`
- `dumpsys-top.txt`
- `dumpsys-meminfo.txt`
- `psi-memory.txt`, `psi-cpu.txt`
- `anr_traces/*` (если удалось снять)

## 6) Быстрая интерпретация

- Много `SIGKILL`/LMK рядом с зависанием -> вероятно memory pressure.
- `Input dispatching timed out` для Winlator activity -> UI-thread/blocking call.
- Долгий старт без падения -> проверить инициализацию контейнера/префикса, I/O latency, cold-start.
