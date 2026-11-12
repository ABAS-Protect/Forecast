/*
    Author: Niklas Dougherty <nd@abas.se>
    Date: 2026-11-05
    Description: Setup table for sales forecast.
*/

namespace ABAS.ABAS_Forecast;

table 50111 "Item Forecast Setup"
{
    DataClassification = CustomerContent;
    AllowInCustomizations = AsReadWrite;
    Caption = 'Item Forecast Setup';
    InherentPermissions = RIMD;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(2; "Forecast Divisor"; Decimal)
        {
            Caption = 'Forecast Parameter';
            MinValue = 0.00001;
        }
        field(3; "Start Date"; Date)
        {
            Caption = 'Start Date';
        }
        field(4; "End Date"; Date)
        {
            Caption = 'End Date';
        }
        field(5; "Hide Zero Sales"; Boolean)
        {
            Caption = 'Hide Zero Sales';
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}