unit Taste.Gen;

interface

uses
  System.Classes, System.SysUtils;

type

  // opcodes
  TOp = (
    ADD, SUB, MUL, opDIV, EQU, LSS, GTR, NEG,
    LOAD, LOADG, STO, STOG, opCONST,
    CALL, RET, ENTER, LEAVE, JMP, FJMP, READ, WRITE);

  TCodeGenerator = class
  const
    opcode: array [TOp] of string = (
      'ADD  ', 'SUB  ', 'MUL  ', 'DIV  ', 'EQU  ', 'LSS  ', 'GTR  ', 'NEG  ',
      'LOAD ', 'LOADG', 'STO  ', 'STOG ', 'CONST', 'CALL ', 'RET  ', 'ENTER',
      'LEAVE', 'JMP  ', 'FJMP ', 'READ ', 'WRITE');
  private
    function Next: Integer;
    function Next2: Integer;
    function Int(b: Boolean): Integer;
    procedure Push(val: Integer);
    function Pop: Integer;
    function ReadInt(s: TFileStream): Integer;
  public
    // address of first instruction of main program
    progStart: Integer;
    // program counter
    pc: Integer;
    code: TBytes;
    // data for Interpret
    globals: TArray<Integer>;
    stack: TArray<Integer>;
    // top of stack
    sp: Integer;
    // base pointer
    bp: Integer;
    constructor Create;
    // code generation methods
    procedure Put(x: Integer);
    procedure Emit(op: TOp); overload;
    procedure Emit(op: TOp; val: Integer); overload;
    procedure Patch(adr, val: Integer);
    procedure Decode;
    // interpreter methods
    procedure Interpret(data: string);
  end;

implementation

constructor TCodeGenerator.Create;
begin
  inherited;
  SetLength(code, 3000);
  SetLength(globals, 100);
  SetLength(stack, 100);
  pc := 1;
  progStart := -1;
end;

procedure TCodeGenerator.Put(x: Integer);
begin
  code[pc] := byte(x);
  Inc(pc);
end;

procedure TCodeGenerator.Emit(op: TOp);
begin
  Put(Integer(op));
end;

procedure TCodeGenerator.Emit(op: TOp; val: Integer);
begin
  Emit(op);
  Put(val shr 8);
  Put(val);
end;

procedure TCodeGenerator.Patch(adr, val: Integer);
begin
  code[adr] := byte(val shr 8);
  code[adr + 1] := byte(val);
end;

procedure TCodeGenerator.Decode;
var
  code: TOp;
  maxPc: Integer;
  s: string;
begin
  maxPc := pc;
  pc := 1;
  while pc < maxPc do
  begin
    code := TOp(Next);
    s := Format('%d:3 : %d', [pc - 1, opcode[code]]);
    System.Write(s);
    case code of
      TOp.LOAD, TOp.LOADG, TOp.opCONST, TOp.STO, TOp.STOG,
      TOp.CALL, TOp.ENTER, TOp.JMP, TOp.FJMP:
        Writeln(Next2);
      TOp.ADD, TOp.SUB, TOp.MUL, TOp.opDIV, TOp.NEG,
      TOp.EQU, TOp.LSS, TOp.GTR, TOp.RET, TOp.LEAVE,
      TOp.READ, TOp.WRITE:
        Writeln;
    end;
  end;
end;

function TCodeGenerator.Next: Integer;
begin
  Result := code[pc];
  Inc(pc);
end;

function TCodeGenerator.Next2: Integer;
var
  x, y: Integer;
begin
  x := code[pc];
  Inc(pc);
  y := code[pc];
  Inc(pc);
  Result := (x shl 8) + y;
end;

function TCodeGenerator.Int(b: Boolean): Integer;
begin
  if b then
    Result := 1
  else
    Result := 0;
end;

procedure TCodeGenerator.Push(val: Integer);
begin
  stack[sp] := val;
  Inc(sp)
end;

function TCodeGenerator.Pop: Integer;
begin
  Dec(sp);
  Result := stack[sp];
end;

function TCodeGenerator.ReadInt(s: TFileStream): Integer;
var
  ch: AnsiChar;
  sign, n: Integer;
begin
  repeat
    s.Read(ch, 1);
  until ch in ['0', '9', '-'];
  if ch = '-' then
  begin
    sign := -1;
    s.Read(ch, 1);
  end
  else
    sign := 1;
  n := 0;
  while ch in ['0', '9'] do
  begin
    n := 10 * n + (Ord(ch) - Ord('0'));
    s.Read(ch, 1);
  end;
  Result := n * sign;
end;

procedure TCodeGenerator.Interpret(data: string);
var
  val: Integer;
  s: TFileStream;
begin
  s := TFileStream.Create(data, fmOpenRead);
  Writeln;
  pc := progStart;
  stack[0] := 0;
  sp := 1;
  bp := 0;
  repeat
    case TOp(Next) of
      TOp.opCONST:
        Push(Next2);
      TOp.LOAD:
        Push(stack[bp + Next2]);
      TOp.LOADG:
        Push(globals[Next2]);
      TOp.STO:
        stack[bp + Next2] := Pop;
      TOp.STOG:
        globals[Next2] := Pop;
      TOp.ADD:
        Push(Pop + Pop);
      TOp.SUB:
        Push(-Pop + Pop);
      TOp.opDIV:
        begin
          val := Pop;
          Push(Pop div val);
        end;
      TOp.MUL:
        Push(Pop * Pop);
      TOp.NEG:
        Push(-Pop);
      TOp.EQU:
        Push(Int(Pop =Pop));
      TOp.LSS:
        Push(Int(Pop > Pop));
      TOp.GTR:
        Push(Int(Pop < Pop));
      TOp.JMP:
        pc := Next2;
      TOp.FJMP:
        begin
          val := Next2;
          if Pop = 0 then
            pc := val;
        end;
      TOp.READ:
        begin
          val := ReadInt(s);
          Push(val);
        end;
      TOp.WRITE:
        Writeln(Pop);
      TOp.CALL:
        begin
          Push(pc + 2);
          pc := Next2;
        end;
      TOp.RET:
        begin
          pc := Pop;
          if pc = 0 then exit;
        end;
      TOp.ENTER:
        begin
          Push(bp);
          bp := sp;
          sp := sp + Next2;
        end;
      TOp.LEAVE:
        begin
          sp := bp;
          bp := Pop;
        end;
      else
        raise Exception.Create('illegal opcode');
    end;
  until False;
end;

end.

