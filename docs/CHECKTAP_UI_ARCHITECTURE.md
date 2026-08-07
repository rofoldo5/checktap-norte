# Arquitectura de presentación CheckTap

## Decisión

La renovación visual conserva los contratos del backend, repositorios, caché,
sincronización, Firebase y navegación principal. La estructura existente no se
migra de forma disruptiva. Se incorpora una capa de presentación modular que
puede evolucionar gradualmente hacia MVVM/Clean:

```text
mobile/lib/
├── core/                    infraestructura transversal y telemetría
├── data/                    persistencia y repositorios existentes
├── features/
│   └── dashboard/
│       ├── domain/          modelos derivados y lógica pura testeable
│       └── presentation/    widgets exclusivos de la funcionalidad
├── models/                  modelos de dominio existentes
├── screens/                 composición de pantallas y control de flujo
├── services/                sesión, sincronización, Firebase y tiempo real
└── ui/
    ├── components/          componentes reutilizables sin lógica de red
    └── theme/               tokens, color, espacio, forma y ThemeData
```

## Reglas de dependencia

1. `ui/` no llama APIs ni accede a SQLite.
2. `features/*/domain` contiene transformaciones puras y pruebas unitarias.
3. Las pantallas coordinan repositorios y estado vigente sin duplicar reglas.
4. Los repositorios continúan siendo la única frontera para datos remotos y
   offline.
5. Los componentes reciben datos y callbacks; no conocen `SessionStore`.

## Evolución recomendada

Cuando se necesiten flujos más complejos, extraer el estado de cada pantalla a
un `ChangeNotifier` o `ValueNotifier` por funcionalidad. La migración debe ser
incremental: primero Tareas, luego Usuarios, Departamentos e Informes.

## Compatibilidad

- Android mínimo: API 23 / Android 6.0.
- iOS mínimo: 14.0.
- Diseño adaptable: teléfono, tablet y ventanas desde 320 px.
- El logo se incluye como activo local y no necesita Internet.
