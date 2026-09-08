# my_build_system_pghttp

Bu klasör, `pgsql-http` PostgreSQL extension'ini (https://github.com/pramsey/pgsql-http) Docker tabanlı ortamlarda derleyip platformlara göre paketler.

- Docker image, `Dockerfile` içinde tanımlanır (Ubuntu 22.04)
- `run_build.sh` scripti container'ı inşa eder ve çalıştırır
- `builder.sh` ise container içinde kaynakları indirir, çeşitli PostgreSQL sürümleri için derler ve `packages/` içine çıktı paketleri koyar.

Kullanım:

```bash
chmod +x run_build.sh
./run_build.sh
```

Notlar:
- Windows için önceden derlenmiş binaryler her zaman bulunmayabilir; Docker image Linux derleme ortamıdır.
- Daha fazla PG sürümü eklemek için `builder.sh` içindeki `TARGET_PG_VERSIONS` dizisini düzenleyebilirsiniz.

