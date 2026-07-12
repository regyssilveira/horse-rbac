---
name: horse-rbac
description: "Guidelines for implementing and configuring the horse-rbac middleware for route-level access control in Horse."
---

# Horse RBAC Middleware AI Coding Skill

This skill guides AI agents in implementing, configuring, and registering the `horse-rbac` middleware inside a Delphi or Lazarus application using the Horse framework.

## 💡 Syntax Reference

Always import the namespace `Horse.RBAC`. The middleware function is named `RBAC`:

```delphi
function RBAC(const APermissions: array of string; const AClaimName: string = 'permissions'; const AVerifyAll: Boolean = False): THorseCallback;
```

### Parameters:
* **`APermissions`**: An array of string containing the permissions required to access the route (e.g. `['pedidos:read']` or `['pedidos:write', 'entidades:write']`).
* **`AClaimName`**: The name of the claim key inside the JWT payload containing the array of user permissions. Defaults to `'permissions'`.
* **`AVerifyAll`**: Lógica de verificação.
  - `False` (Default - **OR logic**): If the user has *at least one* of the specified permissions, access is granted.
  - `True` (**AND logic**): The user must possess *all* specified permissions to access the route.

## ⚙️ Registration Patterns

The middleware must be registered at the route level using an array bracket:

```delphi
// Route requires 'pedidos:read' (OR logic)
THorse.Get('/pedidos', [RBAC(['pedidos:read'])], PedidosHandler);

// Route requires both 'pedidos:write' and 'entidades:write' (AND logic)
THorse.Post('/pedidos', [RBAC(['pedidos:write', 'entidades:write'], 'permissions', True)], CreatePedidoHandler);
```

> [!IMPORTANT]
> The RBAC middleware relies on `Req.Session` to read the token claims. An authentication middleware (such as `horse-jwt`) **must** be registered globally or at the group/route level *before* the RBAC middleware runs.

## 📄 GBSwagger Integration

To document the required scopes and authorization in the Swagger JSON generator, combine the route registration with security attributes or fluent calls:

```delphi
// Controller method annotated with SwagSecurity
[SwagGET('List orders')]
[SwagSecurity('Bearer', ['pedidos:read'])]
procedure GetOrders(Req: THorseRequest; Res: THorseResponse);
```
