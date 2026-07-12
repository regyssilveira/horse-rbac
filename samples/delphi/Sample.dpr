program Sample;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  {$IFDEF FPC}
  fpjson,
  {$ELSE}
  System.JSON,
  {$ENDIF}
  Horse,
  Horse.JWT, // Assume que o desenvolvedor instalou o horse-jwt no projeto dele
  Horse.RBAC in '../../src/Horse.RBAC.pas';

begin
  // 1. Configuração Global de Middlewares
  THorse.Use(HorseJWT('SuaChaveSecretaSuperSegura')); // Valida assinatura do token e joga payload no Req.Session

  // 2. Rotas Protegidas com Controle de Acesso Granular (RBAC)
  
  // Rota de consulta de pedidos: Exige a permissão 'pedidos:read' (Lógica OR - Padrão)
  THorse.Get('/pedidos', [RBAC(['pedidos:read'])],
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('{"message": "Lista de pedidos obtida com sucesso!"}')
         .ContentType('application/json');
    end);

  // Rota de criação de pedidos: Exige a permissão 'pedidos:write'
  THorse.Post('/pedidos', [RBAC(['pedidos:write'])],
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('{"message": "Pedido criado com sucesso!"}')
         .ContentType('application/json');
    end);

  // Rota de configuração do sistema: Exige 'pedidos:write' E 'entidades:write' (Lógica AND)
  THorse.Put('/config', [RBAC(['pedidos:write', 'entidades:write'], 'permissions', True)],
    procedure(Req: THorseRequest; Res: THorseResponse)
    begin
      Res.Send('{"message": "Configuracoes globais atualizadas!"}')
         .ContentType('application/json');
    end);

  // Roda o servidor na porta 9000
  WriteLn('Servidor Horse de Exemplo rodando na porta 9000...');
  THorse.Listen(9000);
end.
