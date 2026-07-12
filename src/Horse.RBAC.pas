unit Horse.RBAC;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
  {$IF DEFINED(HORSE_FPC_FUNCTIONREFERENCES)}
    {$MODESWITCH FUNCTIONREFERENCES+}
  {$ENDIF}
{$ENDIF}

interface

uses
  SysUtils, Classes,
  {$IF DEFINED(FPC)}
    fpjson,
  {$ELSE}
    System.JSON,
  {$ENDIF}
  Horse, Horse.Commons;

function RBAC(const APermissions: array of string; const AClaimName: string = 'permissions'; const AVerifyAll: Boolean = False): THorseCallback;

implementation

function RBAC(const APermissions: array of string; const AClaimName: string = 'permissions'; const AVerifyAll: Boolean = False): THorseCallback;
var
  LRequiredPermissions: TArray<string>;
  I: Integer;
begin
  // Copia as permissões para um array dinâmico local para ser capturado com segurança pela closure
  SetLength(LRequiredPermissions, Length(APermissions));
  for I := Low(APermissions) to High(APermissions) do
    LRequiredPermissions[I] := APermissions[I];

  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF})
    var
      LSession: TJSONObject;
      LPermissionsArray: TJSONArray;
      LHasPermission: Boolean;
      J, K, LIndex: Integer;
      LPermValue: string;
      LRequiredCount: Integer;
      LMatchedCount: Integer;
      LMatchFound: Boolean;
      {$IFDEF FPC}
      LData: TJSONData;
      {$ELSE}
      LValue: TJSONValue;
      {$ENDIF}
    begin
      // 1. Verifica se a sessão existe e é um TJSONObject
      LSession := Req.Session<TJSONObject>;
      if not Assigned(LSession) then
      begin
        Res.Send('Unauthorized').Status(THTTPStatus.Unauthorized);
        raise EHorseCallbackInterrupted.Create;
      end;

      // 2. Localiza a claim que contém as permissões
      {$IFDEF FPC}
      LData := LSession.Find(AClaimName);
      if not Assigned(LData) or not (LData is TJSONArray) then
      begin
        Res.Send('Forbidden').Status(THTTPStatus.Forbidden);
        raise EHorseCallbackInterrupted.Create;
      end;
      LPermissionsArray := TJSONArray(LData);
      {$ELSE}
      LValue := LSession.GetValue(AClaimName);
      if not Assigned(LValue) or not (LValue is TJSONArray) then
      begin
        Res.Send('Forbidden').Status(THTTPStatus.Forbidden);
        raise EHorseCallbackInterrupted.Create;
      end;
      LPermissionsArray := TJSONArray(LValue);
      {$ENDIF}

      // 3. Valida as permissões do array
      LHasPermission := False;
      LRequiredCount := Length(LRequiredPermissions);
      LMatchedCount := 0;

      // Iteramos as permissões requeridas pela rota usando LIndex local da closure
      for LIndex := Low(LRequiredPermissions) to High(LRequiredPermissions) do
      begin
        LMatchFound := False;
        // Compara com as permissões presentes na claim do token
        for J := 0 to Pred(LPermissionsArray.Count) do
        begin
          {$IFDEF FPC}
          LPermValue := LPermissionsArray.Items[J].AsString;
          {$ELSE}
          LPermValue := LPermissionsArray.Items[J].Value;
          {$ENDIF}

          if SameText(LRequiredPermissions[LIndex], LPermValue) then
          begin
            LMatchFound := True;
            Inc(LMatchedCount);
            Break;
          end;
        end;

        if LMatchFound and not AVerifyAll then
        begin
          LHasPermission := True;
          Break;
        end;
      end;

      if AVerifyAll and (LMatchedCount = LRequiredCount) then
        LHasPermission := True;

      // 4. Fluxo de saída
      if LHasPermission then
        Next()
      else
      begin
        Res.Send('Forbidden').Status(THTTPStatus.Forbidden);
        raise EHorseCallbackInterrupted.Create;
      end;
    end;
end;

end.
