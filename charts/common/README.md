# Common Helm Chart

The **Common** chart provides shared **Helm templates (tpl)** used by other CSGHub charts.  
It does **not deploy any service** on its own.

## Usage

Include this chart as a dependency in other charts to reuse templates and shared configurations.

For detailed instructions, see the main CSGHub documentation:  

- [Templates](https://github.com/OpenCSGs/csghub-charts/tree/main/charts/common/templates)

## Conventions

### Booleans: never inside a `merge` block

Sprig's `merge` is backed by `mergo.Merge`, which **skips zero-valued fields**. This means
`merge $dst (dict "enabled" false)` silently keeps `$dst.enabled` instead of writing `false`.

The same trap applies to Sprig's `default` and `dig` when used to look up an optional bool
(`false` is treated as "no value" and the default wins).

**Rule:** a `merge` block must contain only strings/ints/maps. Boolean fields must be applied
separately with `set` + `hasKey`, so an explicit `false` is preserved.

See `_objectStore.tpl`, `_registry.tpl`, and `_gateway.tpl` for the canonical pattern:
`merge` covers non-bool fields; each bool field gets its own `{{ if hasKey . "x" }}{{ set ... "x" .x }}{{ end }}`.

---

_The CSGHub Support Team_