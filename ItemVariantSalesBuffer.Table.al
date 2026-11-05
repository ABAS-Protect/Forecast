/*
    Author: Niklas Dougherty <nd@abas.se>
    Date: 2026-11-05
    Description: Temp table for worksheet columns.
*/

namespace ABAS.ABAS_Forecast;

table 50110 "Item Variant Sales Buffer"
{
    AllowInCustomizations = AsReadWrite;
    TableType = Temporary;

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(2; "Variant Code"; Code[10])
        {
            Caption = 'Variant Code';
        }
        field(3; "Base Item Description"; Text[100])
        {
            Caption = 'Item Description';
        }
        field(4; "Quantity Last Year"; Decimal)
        {
            Caption = 'Quantity Last Year';
        }
        field(5; "Quantity Forecast"; Decimal)
        {
            Caption = 'Quantity Forecast';
        }
    }

    keys
    {
        key(PK; "Item No.", "Variant Code")
        {
            Clustered = true;
        }
    }
}