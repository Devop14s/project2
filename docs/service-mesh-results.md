# Service Mesh Results

## Namespace

`yas-dev`

## mTLS evidence

- sidecar injected: yes
- strict policy applied: yes
- runtime proof:
  - `PeerAuthentication/yas-strict-mtls` is `STRICT`
  - `DestinationRule/yas-default-mtls` is `ISTIO_MUTUAL`
  - business pods in `yas-dev` run `2/2` with `istio-proxy`
- supporting evidence:
  - [work/evidence-mesh-config.txt](../work/evidence-mesh-config.txt)

## Retry evidence

- target services:
  - `yas-dev-order.yas-dev.svc.cluster.local`
  - `yas-dev-tax.yas-dev.svc.cluster.local`
- runtime proof:
  - `VirtualService/order-retry` and `VirtualService/tax-retry` are applied
  - Envoy route config exposes:
    - `retryOn: 5xx,connect-failure,refused-stream`
    - `numRetries: 3`
    - `perTryTimeout: 2s`
  - induced failure test:
    - scale `yas-dev-order` to `0`
    - request through sidecar client returns `HTTP/1.1 503 Service Unavailable`
    - restore `yas-dev-order` to `1` and wait rollout complete
- supporting evidence:
  - [work/evidence-retry.txt](../work/evidence-retry.txt)

## Authorization evidence

- allowed caller:
  - `storefront-bff` → `product`
  - result: `HTTP/1.1 200 OK`
- denied caller:
  - `product` → `search`
  - result: `HTTP/1.1 403 Forbidden`
- supporting evidence:
  - [work/evidence-mtls-allow.txt](../work/evidence-mtls-allow.txt)
  - [work/evidence-mtls-deny.txt](../work/evidence-mtls-deny.txt)

## Observability evidence

- `kiali` service is live in `istio-system`
- current exposure:
  - `NodePort 30001` for Kiali UI
  - `NodePort 32406` for Kiali service port `9090`
- `prometheus` and `istio-ingressgateway` are also live in `istio-system`

## Result

Service mesh requirement is implemented and verified at runtime for:

- strict mTLS
- retry policy present in live Envoy route config
- authorization allow/deny policy enforcement
- Kiali/Prometheus availability

The only thing not embedded in this repo is a screenshot artifact. The runtime evidence above is command-backed and reproducible.
