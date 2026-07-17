# بسته‌های نقشه / گراف آفلاین آبتین

## گراف‌های bundled

### تهران متراکم (پیش‌فرض مسیریابی)
- `tehran_sample_graph.json` — v2 (~900 گره / ~4000 یال)
- `tehran_sample_pois.json`

### گراف استانی (`ir_*`)
هر استان سه فایل دارد:
- `ir_<id>_graph.json` — گراف A*
- `ir_<id>_pois.json` — POI
- `ir_<id>_manifest.json` — متادیتا

استان‌های فعلی:
تهران، البرز، اصفهان، فارس، خراسان رضوی، آذربایجان شرقی، گیلان، مازندران، خوزستان، کرمان، قم، یزد

فهرست: `provinces_index.json`

## بارگذاری در کد
```dart
await routingService.loadProvinceGraph('ir_isfahan');
```
یا از `GraphRegistry.packages`.

## فرمت
nodes: `{id, lat, lon, name?}`
edges: `{a, b, m, speed, class, oneway, name?, modes?}`
