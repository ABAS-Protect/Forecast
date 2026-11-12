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
                            Error(this.ParameterErrorMsg);

                        this.ForecastSetup.Modify();
                        this.PopulateTemporaryData();
                        CurrPage.Update(false);
                    end;
                }
                field("Start Date"; this.ForecastSetup."Start Date")
                {
                    ApplicationArea = All;
                    Caption = 'Start Date';
                    ToolTip = 'Specifies the start date of the historical sales period.';

                    trigger OnValidate()
                    begin
                        this.ValidateDatesAndRefresh();
                    end;
                }
                field("End Date"; this.ForecastSetup."End Date")
                {
                    ApplicationArea = All;
                    Caption = 'End Date';
                    ToolTip = 'Specifies the end date of the historical sales period.';

                    trigger OnValidate()
                    begin
                        this.ValidateDatesAndRefresh();
                    end;
                }
                field("Hide Zero Sales"; this.ForecastSetup."Hide Zero Sales")
                {
                    ApplicationArea = All;
                    Caption = 'Hide Zero Sales';
                    ToolTip = 'Specifies whether items and variants with zero sales in the selected period are hidden.';

                    trigger OnValidate()
                    begin
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
                    Caption = 'Quantity Sold';
                    ToolTip = 'Specifies the total quantity sold for this variant during the selected period.';
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
        ParameterErrorMsg: Label 'The parameter must be greater than zero.';
        DateRangeErrorMsg: Label 'Start Date cannot be later than End Date.';

    local procedure GetOrCreateSetupRecord()
    var
        CurrentYear: Integer;
    begin
        CurrentYear := Date2DMY(WorkDate(), 3);

        if not this.ForecastSetup.Get() then begin
            this.ForecastSetup.Init();
            this.ForecastSetup."Primary Key" := '';
            this.ForecastSetup."Forecast Divisor" := 11;
            this.ForecastSetup."Start Date" := DMY2Date(1, 1, CurrentYear - 1);
            this.ForecastSetup."End Date" := DMY2Date(31, 12, CurrentYear - 1);
            this.ForecastSetup.Insert();
        end else
            if (this.ForecastSetup."Start Date" = 0D) or (this.ForecastSetup."End Date" = 0D) then begin
                if this.ForecastSetup."Start Date" = 0D then
                    this.ForecastSetup."Start Date" := DMY2Date(1, 1, CurrentYear - 1);
                if this.ForecastSetup."End Date" = 0D then
                    this.ForecastSetup."End Date" := DMY2Date(31, 12, CurrentYear - 1);
                this.ForecastSetup.Modify();
            end;
    end;

    local procedure ValidateDatesAndRefresh()
    begin
        if (this.ForecastSetup."Start Date" <> 0D) and (this.ForecastSetup."End Date" <> 0D) then
            if this.ForecastSetup."Start Date" > this.ForecastSetup."End Date" then
                Error(this.DateRangeErrorMsg);

        this.ForecastSetup.Modify();
        this.PopulateTemporaryData();
        CurrPage.Update(false);
    end;

    local procedure PopulateTemporaryData()
    var
        TempFilterBackup: Record "Item Variant Sales Buffer" temporary;
    begin
        TempFilterBackup.CopyFilters(Rec);

        Rec.Reset();
        Rec.DeleteAll();

        if (this.ForecastSetup."Start Date" = 0D) or (this.ForecastSetup."End Date" = 0D) then
            exit;

        if this.ForecastSetup."Hide Zero Sales" then
            this.PopulateSalesOnlyFromQuery()
        else
            this.PopulateAllItemsWithQuery();

        Rec.CopyFilters(TempFilterBackup);

        if Rec.FindFirst() then;
    end;

    local procedure PopulateSalesOnlyFromQuery()
    var
        SalesQuery: Query "Item Variant Sales Query";
        SoldQty: Decimal;
    begin
        SalesQuery.SetRange(PostingDate, this.ForecastSetup."Start Date", this.ForecastSetup."End Date");
        SalesQuery.Open();

        while SalesQuery.Read() do begin
            SoldQty := SalesQuery.InvoicedQuantity * -1;
            if SoldQty <> 0 then begin
                Rec.Init();
                Rec."Item No." := SalesQuery.ItemNo;
                Rec."Variant Code" := SalesQuery.VariantCode;
                Rec."Base Item Description" := SalesQuery.Description;
                Rec."Quantity Last Year" := SoldQty;
                Rec."Quantity Forecast" := this.CalculateForecast(SoldQty);
                Rec.Insert();
            end;
        end;

        SalesQuery.Close();
    end;

    local procedure PopulateAllItemsWithQuery()
    var
        Item: Record Item;
        RealVariant: Record "Item Variant";
        SalesQuery: Query "Item Variant Sales Query";
        SoldQty: Decimal;
    begin
        Item.SetLoadFields("No.", Description);
        RealVariant.SetLoadFields("Item No.", Code);

        if Item.FindSet() then
            repeat
                RealVariant.SetRange("Item No.", Item."No.");
                if RealVariant.FindSet() then
                    repeat
                        this.InsertEmptyBufferRow(Item."No.", RealVariant.Code, Item.Description);
                    until RealVariant.Next() = 0
                else
                    this.InsertEmptyBufferRow(Item."No.", '', Item.Description);
            until Item.Next() = 0;

        SalesQuery.SetRange(PostingDate, this.ForecastSetup."Start Date", this.ForecastSetup."End Date");
        SalesQuery.Open();

        while SalesQuery.Read() do begin
            SoldQty := SalesQuery.InvoicedQuantity * -1;
            if (SoldQty <> 0) and Rec.Get(SalesQuery.ItemNo, SalesQuery.VariantCode) then begin
                Rec."Quantity Last Year" := SoldQty;
                Rec."Quantity Forecast" := this.CalculateForecast(SoldQty);
                Rec.Modify();
            end;
        end;

        SalesQuery.Close();
    end;

    local procedure InsertEmptyBufferRow(NewItemNo: Code[20]; NewVariantCode: Code[10]; NewItemDescription: Text[100])
    begin
        Rec.Init();
        Rec."Item No." := NewItemNo;
        Rec."Variant Code" := NewVariantCode;
        Rec."Base Item Description" := NewItemDescription;
        Rec."Quantity Last Year" := 0;
        Rec."Quantity Forecast" := 0;
        Rec.Insert();
    end;

    local procedure CalculateForecast(SoldQty: Decimal): Decimal
    begin
        if this.ForecastSetup."Forecast Divisor" <> 0 then
            exit((3 * SoldQty) / this.ForecastSetup."Forecast Divisor");
        exit(0);
    end;
}