/*
    Author: Niklas Dougherty <nd@abas.se>
    Date: 2026-11-12
    Description: One SQL group call rather than thousand calls.
*/

namespace ABAS.ABAS_Forecast;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;

query 50120 "Item Variant Sales Query"
{
    QueryType = Normal;
    Caption = 'Item Variant Sales Query';

    elements
    {
        dataitem(ValueEntry; "Value Entry")
        {
            DataItemTableFilter = "Item Ledger Entry Type" = const(Sale);

            filter(PostingDate; "Posting Date")
            {
            }
            column(ItemNo; "Item No.")
            {
            }
            column(VariantCode; "Variant Code")
            {
            }
            column(InvoicedQuantity; "Invoiced Quantity")
            {
                Method = Sum;
            }

            dataitem(Item; Item)
            {
                DataItemLink = "No." = ValueEntry."Item No.";
                SqlJoinType = InnerJoin;

                column(Description; Description)
                {
                }
            }
        }
    }
}