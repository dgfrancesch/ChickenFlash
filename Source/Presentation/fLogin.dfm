object Form1: TForm1
  Width = 640
  Height = 480
  object lblError: TWebLabel
    Left = 235
    Top = 312
    Width = 102
    Height = 15
    HeightPercent = 100.000000000000000000
    WidthPercent = 100.000000000000000000
  end
  object edtUsuario: TWebEdit
    Left = 208
    Top = 144
    Width = 121
    Height = 22
    HeightPercent = 100.000000000000000000
    Text = 'edtUsuario'
    WidthPercent = 100.000000000000000000
  end
  object edtClave: TWebEdit
    Left = 208
    Top = 184
    Width = 121
    Height = 22
    ChildOrder = 1
    HeightPercent = 100.000000000000000000
    Text = 'edtUsuario'
    WidthPercent = 100.000000000000000000
  end
  object btnEntrar: TWebButton
    Left = 233
    Top = 240
    Width = 96
    Height = 25
    Caption = 'btnEntrar'
    ChildOrder = 2
    HeightPercent = 100.000000000000000000
    WidthPercent = 100.000000000000000000
    OnClick = btnEntrarClick
  end
end
