/*
    Author: Niklas Dougherty <nd@abas.se>
    Date: 2026-11-05
    Description: Compute simple sales forecast for items + variants.
*/

namespace ABAS.ABAS_Forecast;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;

page 50115 "Item Sales Forecast"
{
    PageType = Worksheet;
    ApplicationArea = All;
    UsageCategory = Tasks;
    SourceTable = "Item Variant Sales Buffer";
    SourceTableTemporary = true;
    Caption = 'ABAS Item Sales Forecast (LS)';

    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(GeneralConfiguration)
            {
                Caption = 'Forecast Parameters';

                field("Forecast Divisor"; this.ForecastSetup."Forecast Divisor")
                {
                    ApplicationArea = All;
                    Caption = 'Forecast parameter';
                    ToolTip = 'The permanent base value used in calculations: 3 * (Sales Last Year) / parameter.';

                    trigger OnValidate()
                    begin
                        if this.ForecastSetup."Forecast Divisor" <= 0 then
                            Error('The divisor must be greater than zero.');

                        this.ForecastSetup.Modify();

                        this.PopulateTemporaryData();
                        CurrPage.Update(false);
                    end;
                }
            }

            repeater(Group)
            {
                Editable = false;

                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item number.';
                }
                field(BaseItemDescription; Rec."Base Item Description")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the description of the base item.';
                }
                field(VariantCode; Rec."Variant Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the variant code.';
                }
                field(QuantityLastYear; Rec."Quantity Last Year")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0;
                    ToolTip = 'Specifies the total quantity sold for this variant last year.';
                }
                field(QuantityForecast; Rec."Quantity Forecast")
                {
                    ApplicationArea = All;
                    DecimalPlaces = 0;
                    ToolTip = 'Specifies the forecasted unit quantity.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.GetOrCreateSetupRecord();
        this.PopulateTemporaryData();
    end;

    trigger OnFindRecord(Which: Text): Boolean
    begin
        exit(Rec.Find(Which));
    end;

    trigger OnNextRecord(Steps: Integer): Integer
    begin
        exit(Rec.Next(Steps));
    end;

    var
        ForecastSetup: Record "Item Forecast Setup";

    local procedure GetOrCreateSetupRecord()
    begin
        if not this.ForecastSetup.Get() then begin
            this.ForecastSetup.Init();
            this.ForecastSetup."Primary Key" := '';
            this.ForecastSetup."Forecast Divisor" := 11;
            this.ForecastSetup.Insert();
        end;
    end;

    local procedure PopulateTemporaryData()
    var
        Item: Record Item;
        RealVariant: Record "Item Variant";
        StartDate: Date;
        EndDate: Date;
        CurrentYear: Integer;
        HasVariants: Boolean;
    begin
        CurrentYear := Date2DMY(WorkDate(), 3);
        StartDate := DMY2Date(1, 1, CurrentYear - 1);
        EndDate := DMY2Date(31, 12, CurrentYear - 1);

        Rec.Reset();
        Rec.DeleteAll();

        if Item.FindSet() then
            repeat
                RealVariant.Reset();
                RealVariant.SetRange("Item No.", Item."No.");
                HasVariants := RealVariant.FindSet();

                if HasVariants then
                    repeat
                        this.InsertBufferRow(Item."No.", RealVariant.Code, Item.Description, StartDate, EndDate);
                    until RealVariant.Next() = 0
                else
                    this.InsertBufferRow(Item."No.", '', Item.Description, StartDate, EndDate);
            until Item.Next() = 0;

        if Rec.FindFirst() then;
    end;

    local procedure InsertBufferRow(
        NewItemNo: Code[20];
        NewVariantCode: Code[10];
        NewItemDescription: Text[100];
        StartDate: Date;
        EndDate: Date
    )
    var
        ValueEntry: Record "Value Entry";
    begin
        Rec.Init();
        Rec."Item No." := NewItemNo;
        Rec."Variant Code" := NewVariantCode;
        Rec."Base Item Description" := NewItemDescription;

        ValueEntry.Reset();
        ValueEntry.SetRange("Item No.", NewItemNo);
        ValueEntry.SetRange("Variant Code", NewVariantCode);
        ValueEntry.SetRange("Posting Date", StartDate, EndDate);
        ValueEntry.SetRange("Item Ledger Entry Type", ValueEntry."Item Ledger Entry Type"::Sale);

        if ValueEntry.CalcSums("Invoiced Quantity") then
            Rec."Quantity Last Year" := ValueEntry."Invoiced Quantity" * -1;

        if this.ForecastSetup."Forecast Divisor" <> 0 then
            Rec."Quantity Forecast" := (3 * Rec."Quantity Last Year") / this.ForecastSetup."Forecast Divisor"
        else
            Rec."Quantity Forecast" := 0;

        Rec.Insert();
    end;
}