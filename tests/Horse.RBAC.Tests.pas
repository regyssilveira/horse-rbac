unit Horse.RBAC.Tests;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
  SysUtils, Classes,
  {$IF DEFINED(FPC)}
    fpjson, fphttpclient,
  {$ELSE}
    System.JSON, System.Net.HttpClient, System.Net.URLClient,
  {$ENDIF}
  Horse, Horse.Commons, Horse.RBAC;

type
  THorseRBACTests = class
  private
    class var FPort: Integer;
    class var FServerRunning: Boolean;
    class procedure StartServer;
    class procedure StopServer;
    class function SendRequest(const APath: string; const APermissionsClaimJson: string; out AResponseCode: Integer): string;
  public
    class function RunAllTests: Boolean;
  end;

implementation

{ THorseRBACTests }

class procedure THorseRBACTests.StartServer;
begin
  FPort := 9099;
  
  // Rota A: Exige 'pedidos:read' (Lógica OR - Padrão)
  THorse.Get('/pedidos-read', [
    procedure(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF})
    var
      LAuthHeader: string;
      LJson: TJSONObject;
      {$IFDEF FPC}
      LParser: TJSONParser;
      LData: TJSONData;
      {$ENDIF}
    begin
      // Mock de injeção da sessão via header de teste "X-Test-Session"
      LAuthHeader := Req.Headers['X-Test-Session'];
      if not LAuthHeader.IsEmpty then
      begin
        {$IFDEF FPC}
        LParser := TJSONParser.Create(LAuthHeader);
        try
          LData := LParser.Parse;
          if LData is TJSONObject then
            Req.Session(TJSONObject(LData));
        finally
          LParser.Free;
        end;
        {$ELSE}
        LJson := TJSONObject.ParseJSONValue(LAuthHeader) as TJSONObject;
        Req.Session(LJson, True);
        {$ENDIF}
      end;
      Next();
    end,
    RBAC(['pedidos:read'])
  ],
  procedure(Req: THorseRequest; Res: THorseResponse)
  begin
    Res.Send('OK Read');
  end);

  // Rota B: Exige 'pedidos:write' E 'entidades:write' (Lógica AND)
  THorse.Get('/pedidos-write-and', [
    procedure(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF})
    var
      LAuthHeader: string;
      LJson: TJSONObject;
      {$IFDEF FPC}
      LParser: TJSONParser;
      LData: TJSONData;
      {$ENDIF}
    begin
      LAuthHeader := Req.Headers['X-Test-Session'];
      if not LAuthHeader.IsEmpty then
      begin
        {$IFDEF FPC}
        LParser := TJSONParser.Create(LAuthHeader);
        try
          LData := LParser.Parse;
          if LData is TJSONObject then
            Req.Session(TJSONObject(LData));
        finally
          LParser.Free;
        end;
        {$ELSE}
        LJson := TJSONObject.ParseJSONValue(LAuthHeader) as TJSONObject;
        Req.Session(LJson, True);
        {$ENDIF}
      end;
      Next();
    end,
    RBAC(['pedidos:write', 'entidades:write'], 'permissions', True)
  ],
  procedure(Req: THorseRequest; Res: THorseResponse)
  begin
    Res.Send('OK Write AND');
  end);

  // Inicia o servidor Horse em uma Thread
  TThread.CreateAnonymousThread(
    procedure
    begin
      THorse.Listen(FPort);
    end).Start;

  // Aguarda inicialização física
  Sleep(300);
  FServerRunning := True;
end;

class procedure THorseRBACTests.StopServer;
begin
  if FServerRunning then
  begin
    THorse.StopListen;
    FServerRunning := False;
    Sleep(200); // Dá um tempo para liberação do socket
  end;
end;

class function THorseRBACTests.SendRequest(const APath: string; const APermissionsClaimJson: string; out AResponseCode: Integer): string;
{$IFDEF FPC}
var
  LClient: TFPHTTPClient;
  LUrl: string;
begin
  LClient := TFPHTTPClient.Create(nil);
  try
    LUrl := 'http://localhost:' + IntToStr(FPort) + APath;
    LClient.AddHeader('Connection', 'close');
    if APermissionsClaimJson <> '' then
      LClient.AddHeader('X-Test-Session', APermissionsClaimJson);
    try
      Result := LClient.Get(LUrl);
      AResponseCode := LClient.ResponseStatusCode;
    except
      on E: EHTTPClient do
      begin
        AResponseCode := LClient.ResponseStatusCode;
        Result := E.Message;
      end;
    end;
  finally
    LClient.Free;
  end;
end;
{$ELSE}
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  LUrl: string;
begin
  LClient := THTTPClient.Create;
  try
    LUrl := 'http://localhost:' + IntToStr(FPort) + APath;
    LClient.CustomHeaders['Connection'] := 'close';
    if APermissionsClaimJson <> '' then
      LClient.CustomHeaders['X-Test-Session'] := APermissionsClaimJson;
    try
      LResponse := LClient.Get(LUrl);
      AResponseCode := LResponse.StatusCode;
      Result := LResponse.ContentAsString;
    except
      on E: Exception do
      begin
        AResponseCode := 500;
        Result := E.Message;
      end;
    end;
  finally
    LClient.Free;
  end;
end;
{$ENDIF}

class function THorseRBACTests.RunAllTests: Boolean;
var
  LCode: Integer;
  LSuccess: Boolean;
begin
  LSuccess := True;
  WriteLn('Iniciando Testes do Middleware horse-rbac...');
  StartServer;
  try
    // Teste 1: Sem token / Sem Session (Espera 401 Unauthorized)
    Write('Teste 1: Acesso a rota sem informacao de sessao... ');
    SendRequest('/pedidos-read', '', LCode);
    if LCode = 401 then
      WriteLn('[OK] (401)')
    else
    begin
      WriteLn('[FALHOU] (Esperado 401, obtido ' + IntToStr(LCode) + ')');
      LSuccess := False;
    end;

    // Teste 2: Session existe mas sem a claim de permissões (Espera 403 Forbidden)
    Write('Teste 2: Acesso com sessao mas sem a claim de permissoes... ');
    SendRequest('/pedidos-read', '{"roles": ["user"]}', LCode);
    if LCode = 403 then
      WriteLn('[OK] (403)')
    else
    begin
      WriteLn('[FALHOU] (Esperado 403, obtido ' + IntToStr(LCode) + ')');
      LSuccess := False;
    end;

    // Teste 3: Rota OR com permissão suficiente (Espera 200 OK)
    Write('Teste 3: Rota com logica OR e permissao suficiente... ');
    SendRequest('/pedidos-read', '{"permissions": ["pedidos:read", "pedidos:write"]}', LCode);
    if LCode = 200 then
      WriteLn('[OK] (200)')
    else
    begin
      WriteLn('[FALHOU] (Esperado 200, obtido ' + IntToStr(LCode) + ')');
      LSuccess := False;
    end;

    // Teste 4: Rota OR com permissão insuficiente (Espera 403 Forbidden)
    Write('Teste 4: Rota com logica OR e permissao insuficiente... ');
    SendRequest('/pedidos-read', '{"permissions": ["pedidos:write"]}', LCode);
    if LCode = 403 then
      WriteLn('[OK] (403)')
    else
    begin
      WriteLn('[FALHOU] (Esperado 403, obtido ' + IntToStr(LCode) + ')');
      LSuccess := False;
    end;

    // Teste 5: Rota AND com permissões insuficientes parciais (Espera 403 Forbidden)
    Write('Teste 5: Rota com logica AND e permissoes parciais... ');
    SendRequest('/pedidos-write-and', '{"permissions": ["pedidos:write"]}', LCode);
    if LCode = 403 then
      WriteLn('[OK] (403)')
    else
    begin
      WriteLn('[FALHOU] (Esperado 403, obtido ' + IntToStr(LCode) + ')');
      LSuccess := False;
    end;

    // Teste 6: Rota AND com todas as permissões exigidas (Espera 200 OK)
    Write('Teste 6: Rota com logica AND e todas as permissoes... ');
    SendRequest('/pedidos-write-and', '{"permissions": ["pedidos:write", "entidades:write"]}', LCode);
    if LCode = 200 then
      WriteLn('[OK] (200)')
    else
    begin
      WriteLn('[FALHOU] (Esperado 200, obtido ' + IntToStr(LCode) + ')');
      LSuccess := False;
    end;

  finally
    StopServer;
  end;

  Result := LSuccess;
end;

end.
