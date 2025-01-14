{*******************************************************************************
  *                                                                             *
  *   Delphi Twitter (X) Library                                                *
  *                                                                             *
  *   Developer: Silas AIKO                                                     *
  *                                                                             *
  *   Description:                                                              *
  *   This Delphi library provides functionality for interacting with the       *
  *   Twitter (X) API v1 and v2.                                                *
  *                                                                             *
  *   Compatibility: VCL, FMX                                                   *
  *   Tested on Delphi: 11 Alexandria  CE                                       *
  *   Version: 1.1.0                                                            *
  *                                                                             *
  *   License: MIT License (See LICENSE file for details)                       *
  *                                                                             *
  *                                                                             *
  *******************************************************************************}

unit Twitter.Core;

interface

uses
  System.SysUtils, System.Classes,FMX.Dialogs,System.JSON,System.Net.Mime,
  System.Net.HttpClientComponent, System.Net.HttpClient, System.NetEncoding,
  System.DateUtils,IdGlobal, IdCoderMIME, System.Hash, REST.Json,
  Twitter.Api.Types,System.Rtti;


procedure CloseTwitterClient;

function  URLEncode(source:string):string;
function  URLContains(const URL: string): Boolean;


function DELETE(AUrl:String): TTweetRespDeleted;
function POST(AMethod:String; AUrl:String; AParams:TStringStream;AHeadParams:TStringList=nil): String;
function POST_FILE(AUrl:String; AMethod: String; AParams:TMultipartFormData):String;

var
  ClientBase    : TNetHTTPClient;
  LRespToken    : TTwitterSign;
  User          : TTwitterCredentials;

implementation

function URLEncode(source:string):string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(source) do
  begin
    if not CharInSet(source[i], ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '~', '.']) then
      Result := Result + '%' + IntToHex(Ord(source[i]), 2)
    else
      Result := Result + source[i];
  end;
 end;

function GenerateNonce:string ;
var
  RandomData: TBytes;
  Base64String: string;
  I: Integer;
begin
  SetLength(RandomData, 32);
  for I := 0 to Length(RandomData) - 1 do RandomData[I] := Random(256);
  Base64String := TNetEncoding.Base64.EncodeBytesToString(RandomData);
  Result := '';
  for I := 1 to Length(Base64String) do
  begin
    if (Base64String[I] >= 'A') and (Base64String[I] <= 'Z') or
       (Base64String[I] >= 'a') and (Base64String[I] <= 'z') or
       (Base64String[I] >= '0') and (Base64String[I] <= '9') then
       Result := Result + Base64String[I];
  end;
end;

function CollectParams(AParams:TStringList):string;
begin
  for var I:= 0 to AParams.Count-1 do
  begin
    Result := Result +
    AParams.KeyNames[I]+'='+AParams.ValueFromIndex[I];
    if (I<AParams.Count-1) then  Result:=Result+'&';
  end;
end;

function BuildHeader(AParams:TStringList):string;
begin
  Result := Result + 'OAuth ';
  for var I:= 0 to AParams.Count-1 do
    begin
      Result := Result +
      URLEncode(AParams.KeyNames[I])+'='+'"'+URLEncode(AParams.ValueFromIndex[I])+'"';
      if (I<AParams.Count-1) then  Result:=Result+' ,';
    end;
end;

function TwitterOAuth1(AURL, AMethod: string;AParams: TStringList=nil): Boolean;
var
  OAuthParam: TStringList;
begin
  Result := False;
  try
    AMethod := UpperCase(AMethod);

    // Initialize OAuth parameter list
    OAuthParam := TStringList.Create;

    try
      OAuthParam.Values['oauth_consumer_key']     := User._ConsumerKey;
      OAuthParam.Values['oauth_token']            := User._AccessToken;
      OAuthParam.Values['oauth_signature_method'] := 'HMAC-SHA1';
      OAuthParam.Values['oauth_timestamp']        := IntToStr(DateTimeToUnix(Now));
      OAuthParam.Values['oauth_nonce']            := GenerateNonce;
      OAuthParam.Values['oauth_version']          := '1.0';
      if (AParams<>nil) then OAuthParam.AddStrings(AParams);
      OAuthParam.Sort;

      // Collect Parameters
      var tmpParms := TStringList.Create;
      try
        tmpParms.AddStrings(OAuthParam);

        for var I := 0 to tmpParms.Count - 1 do
        tmpParms.ValueFromIndex[I] := URLEncode(tmpParms.ValueFromIndex[I]);
        tmpParms.Sort;

        var ParamString := CollectParams(tmpParms);

        // Creating the signature base string
        var SignatureBaseString := Format('%s&%s&%s',
          [AMethod, URLEncode(AURL), URLEncode(ParamString)]);

        // Getting a signing key
        var SignatureKey := Format('%s&%s', [URLEncode(User._ConsumerSecret), URLEncode(User._TokenSecret)]);

        // Calculating the signature
        var tmpSignature := THashSHA1.GetHMACAsBytes(SignatureBaseString, SignatureKey);
        var Signature    := TNetEncoding.Base64.EncodeBytesToString(tmpSignature);

        // Add oauth_signature to parameters
        OAuthParam.Values['oauth_signature'] := Signature;
        OAuthParam.Sort;

        // Build OAuth Header
        var Header := BuildHeader(OAuthParam);


        // Add the new header to ClientBase
        ClientBase.CustHeaders.Add('Authorization', Header);

        Result := True; // Mark operation as successful
      finally
        tmpParms.Free;
      end;
    finally
      OAuthParam.Free;
    end;
  except
    on E: Exception do
    begin
      ShowMessage('Error during OAuth authentication: ' + E.Message);
      Result := False; // Mark operation as failed
    end;
  end;
end;


procedure CloseTwitterClient;
begin
  FreeAndNil(ClientBase);
end;


function POST(AMethod:String;AUrl:String;AParams:TStringStream;AHeadParams:TStringList=nil): String;
begin
   Result := EmptyStr;
   TwitterOAuth1(AUrl, AMethod,AHeadParams);
   try
    Result := ClientBase.Post(AUrl,AParams).ContentAsString(TEncoding.UTF8);
   except
     on E : ENetHTTPClientException do
      begin
        ShowMessage('Error: ' + E.Message);
      end;
   end;
end;

function POST_FILE(AUrl:String; AMethod: String; AParams:TMultipartFormData):String;
begin
   Result := '';
   ClientBase.ContentType := 'multipart/form-data';
   TwitterOAuth1(AURL,AMethod);
   try
    Result := ClientBase.Post(AUrl,AParams).ContentAsString(TEncoding.UTF8);
   except
     on E : ENetHTTPClientException do
      begin
        ShowMessage('Error: ' + E.Message);
      end;
   end;
   ClientBase.ContentType := 'application/json';
end;

function DELETE(AUrl:String):TTweetRespDeleted;
begin
   Result := nil;
   try
    TwitterOAuth1(AURL,'DELETE');
    var tmp := ClientBase.Delete(AUrl).ContentAsString(TEncoding.UTF8);
    Result  := TJSON.JsonToObject<TTweetRespDeleted>
    (tmp,[joIgnoreEmptyArrays,joIgnoreEmptyStrings]);
   except
     on E : ENetHTTPClientException do
      begin
        ShowMessage('Error: ' + E.Message);
      end;
   end;
end;


function URLContains(const URL: string): Boolean;
begin
  Result := Pos('denied=', URL) > 0;
end;

initialization
  ClientBase := TNetHTTPClient.Create(nil);
  ClientBase.ContentType  := 'x-www-form-urlencoded';
end.

