# Лабораторная работа №9: Настройка IPv6 в Docker и сравнение пакетов IPv4/IPv6

## Цель работы
1. Включить и настроить поддержку IPv6 в Docker Desktop на macOS.
2. Создать контейнерную сеть с двойным стеком (IPv4 + IPv6).
3. Выполнить захват сетевого трафика и проанализировать заголовки пакетов ICMP/ICMPv6.
4. Сравнить архитектуру, поля и особенности обработки пакетов протоколов IPv4 и IPv6.

## Окружение
| Параметр | Значение |
|----------|----------|
| ОС | macOS 12 (Monterey) |
| Docker Desktop | 4.25.2 (129061) |
| Базовый образ | `alpine:latest` |
| Инструменты анализа | `tcpdump`, `tshark` (Wireshark CLI) |
| Тип сети | `bridge` (двойной стек) |

---

## Ход выполнения

### 1. Включение IPv6 в Docker Desktop
В `Settings → Docker Engine` добавлены параметры:
```
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:dead:beef::/48"
}
```

### 2. Создание сети с двойным стеком
```
docker network create \
  --driver bridge \
  --ipv6 \
  --subnet 10.99.0.0/16 \
  --subnet fd00:1122:3344::/64 \
  ipv6lab-net
```

### 3. Запуск контейнеров и установка tcpdump
```
docker rm -f c1 c2 2>/dev/null
docker run -d --name c1 --network ipv6lab-net alpine sleep infinity
docker run -d --name c2 --network ipv6lab-net alpine sleep infinity
docker exec c1 apk add --no-cache tcpdump
docker exec c2 apk add --no-cache tcpdump
```

### 4. Получение адресов и проверка связности
| Контейнер | IPv4 | IPv6 |
|----------|----------|---------|
| c1 | 10.99.0.2/16 | d00:1122:3344::2/64 |
| c2 | 10.99.0.3/16 | fd00:1122:3344::3/64 |

Проверка пинга: ping -c 4 <IPv4> и ping -6 -c 4 <IPv6> → 0% packet loss

### 5. Захват трафика
```
# IPv4
docker exec c1 tcpdump -i eth0 -w /tmp/ipv4.pcap -c 4 host 10.99.0.3 &
docker exec c2 ping -c 4 10.99.0.2
docker cp c1:/tmp/ipv4.pcap ./lab9_ipv4.pcap

# IPv6
docker exec c1 tcpdump -i eth0 -w /tmp/ipv6.pcap -c 4 host fd00:1122:3344::3 &
docker exec c2 ping -6 -c 4 fd00:1122:3344::2
docker cp c1:/tmp/ipv6.pcap ./lab9_ipv6.pcap
```

### 6. Вывод tshark

IPv4 (lab9_ipv4.pcap)
```
Internet Protocol Version 4, Src: 10.99.0.3, Dst: 10.99.0.2
    0100 .... = Version: 4
    .... 0101 = Header Length: 20 bytes (5)
    Total Length: 84
    Time to Live: 64
    Protocol: ICMP (1)
    Header Checksum: 0xb24e [validation disabled]
Internet Control Message Protocol
    Type: Echo (ping) request (8)
```

IPv6 (lab9_ipv6.pcap)
```
Internet Protocol Version 6, Src: fd00:1122:3344::3, Dst: fd00:1122:3344::2
    0110 .... = Version: 6
    Payload Length: 64
    Next Header: ICMPv6 (58)
    Hop Limit: 64
Internet Control Message Protocol v6
    Type: Echo (ping) request (128)
```

### Сравнительная таблица заголовков
| Поле | IPv4 (из захвата) | IPv6 (из захвата) | Комментарий |
| ---- | ------------------| ----------------- | ----------- |
| Version | 4 | 6 | Идентификатор протокола |
| Header Length | 20 bytes (IHL=5) | 40 bytes (фиксировано) | IPv6 не имеет поля IHL |
| Length Field | Total Length: 84 | Payload Length: 64 | IPv6 учитывает только полезную нагрузку | 
| TTL/Hop Limit | TTL: 64 | Hop Limit: 64 | Аналогичная семантика, разное название |
| Protocol/Next Header | ICMP (1) | ICMPv6 (58) | В IPv6 указывает на следующий заголовок или протокол |
| Header Checksum | 0xb24e | Отсутствует | В IPv6 проверка перенесена на уровни TCP/UDP |
| ICMP Type | 8 (Echo Request) | 128 (Echo Request) | Разные пространства кодов |
| Source Address | 10.99.0.3 (32 bit) | fd00:1122:3344::3 (128 bit) | ULA-адрес, аналог 192.168.0.0/16 |

### Быстрый запуск
```
git clone https://github.com/DrPAHAN/lab9/
cd lab9
chmod +x analize.sh
./analize.sh
```

### Вывод
Docker Desktop на macOS успешно поддерживает IPv6 при явной конфигурации daemon.json. Пользовательские сети автоматически назначают адреса обоих семейств.
Захват подтвердил архитектурные различия:
IPv6 имеет фиксированный заголовок (40 байт), что упрощает аппаратную обработку маршрутизаторами.
Контрольная сумма заголовка в IPv6 отсутствует, снижая задержку на каждом узле.
Поле TTL заменено на Hop Limit, а Protocol на Next Header, что позволяет гибко использовать Extension Headers.
Фрагментация в IPv6 вынесена из основного заголовка и выполняется только источником.
Экспериментально подтверждена полная совместимость ICMP/ICMPv6 с современными контейнерными сетями. Оба стека работают параллельно без конфликтов маршрутизации внутри Docker bridge.
