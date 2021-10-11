object Form1: TForm1
  Left = 174
  Top = 174
  Width = 870
  Height = 640
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 656
    Top = 0
    Width = 206
    Height = 606
    Align = alRight
    TabOrder = 0
    object Label1: TLabel
      Left = 28
      Top = 16
      Width = 109
      Height = 13
      Caption = 'Циклическая частота'
    end
    object Label2: TLabel
      Left = 32
      Top = 76
      Width = 124
      Height = 14
      Caption = 'Коэффициент затухания'
    end
    object Label3: TLabel
      Left = 40
      Top = 139
      Width = 82
      Height = 13
      Caption = 'Начальный угол'
    end
    object Button1: TButton
      Left = 40
      Top = 224
      Width = 113
      Height = 25
      Caption = 'Start'
      TabOrder = 0
      OnClick = Button1Click
    end
    object Edit1: TEdit
      Left = 56
      Top = 42
      Width = 57
      Height = 21
      TabOrder = 1
      Text = '4'
      OnChange = Edit1Change
    end
    object Edit2: TEdit
      Left = 56
      Top = 100
      Width = 57
      Height = 22
      TabOrder = 2
      Text = '0.5'
      OnChange = Edit2Change
    end
    object Edit3: TEdit
      Left = 64
      Top = 163
      Width = 57
      Height = 20
      TabOrder = 3
      Text = '90'
      OnChange = Edit3Change
    end
  end
end
