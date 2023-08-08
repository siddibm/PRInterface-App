xmlport 65007 "PRI-Bridge-CustomerCreditCheck"
{

    Caption = 'Bridge - CustomerCreditCheck';
    DefaultFieldsValidation = false;
    FormatEvaluate = Xml;
    UseDefaultNamespace = true;

    schema
    {
        textelement(CustomersCreditLimitCheck)
        {
            textelement(thirdPartyAppId)
            {
                MaxOccurs = Once;
                MinOccurs = Zero;
            }
            tableelement(Customer; Customer)
            {
                XmlName = 'Customer';
                SourceTableView = SORTING("No.");
                UseTemporary = true;
                textelement(thirdPartyRecordId)
                {
                    MaxOccurs = Once;
                    MinOccurs = Zero;
                }
                fieldelement(customerNo; Customer."No.")
                {
                    MaxOccurs = Once;
                    MinOccurs = Zero;
                }
                fieldelement(contactNo; Customer."Primary Contact No.")
                {
                    MaxOccurs = Once;
                    MinOccurs = Zero;
                }
                textelement(blocked)
                {
                    MaxOccurs = Once;
                    MinOccurs = Zero;

                    trigger OnBeforePassVariable()
                    begin
                        // Need to validate the value type
                        blocked := Format(Customer.Blocked <> Customer.Blocked::" ", 0, 9);
                    end;
                }
                fieldelement(hasCreditLimit; Customer."Privacy Blocked")
                {
                    MaxOccurs = Once;
                    MinOccurs = Zero;
                }
                fieldelement(creditLimitAmountLCY; Customer."Credit Limit (LCY)")
                {
                    MaxOccurs = Once;
                    MinOccurs = Zero;
                }
                fieldelement(availableCreditAmountLCY; Customer."Budgeted Amount")
                {
                    MaxOccurs = Once;
                    MinOccurs = Zero;
                }
                fieldelement(overdueAmountLCY; Customer."Prepayment %")
                {
                    MinOccurs = Zero;
                }
                fieldelement(customerBalance; Customer.Balance)
                {
                    MinOccurs = Zero;
                }
                fieldelement(customerBalanceLCY; Customer."Balance (LCY)")
                {
                    MinOccurs = Zero;
                }

                trigger OnAfterGetRecord()
                var
                    lTempText: Text;
                    lContact: Record Contact;
                    lAvailAmt: Decimal;
                    lCreditLimitValue: Decimal;
                begin
                    CheckCreditLimit(Customer, lAvailAmt, lTempText);
                    Customer."Budgeted Amount" := lAvailAmt; // Use "Budgeted Amount" field to pass value type (decimal)

                    //lCreditLimitValue := Customer.CalcAvailableAdditonalCreditLCY() + Customer."Credit Limit (LCY)";
                    lCreditLimitValue := Customer."Credit Limit (LCY)";
                    Customer."Credit Limit (LCY)" := lCreditLimitValue;
                    //Customer."Credit Limit" := lCreditLimitValue <> 0;

                    Customer."Prepayment %" := Customer.CalcOverdueBalance; // Use "Prepayment %" field to pass value type (decimal)

                    thirdPartyRecordId := BridgeIntegration.GetExternalRecordID(Customer, thirdPartyAppId);
                    if thirdPartyRecordId = '' then begin
                        lContact."No." := Customer."Primary Contact No.";
                        thirdPartyRecordId := BridgeIntegration.GetExternalRecordID(lContact, thirdPartyAppId);
                    end;
                    if Customer."No." = '' then
                        Customer.Blocked := Customer.Blocked::All;
                end;

                trigger OnBeforeInsertRecord()
                var
                    lContactBusRel: Record "Contact Business Relation";
                    lContact: Record Contact;
                    lCustomer: Record Customer;
                    lRecordRef: RecordRef;
                begin
                    if BridgeIntegration.GetRecordRef(thirdPartyAppId, thirdPartyRecordId, lRecordRef) then
                        case lRecordRef.Number of
                            DATABASE::Customer:
                                Customer."No." := lRecordRef.Field(lCustomer.FieldNo("No.")).Value;
                            DATABASE::Contact:
                                Customer."Primary Contact No." := lRecordRef.Field(lContact.FieldNo("No.")).Value;
                        end;

                    if (Customer."No." = '') and (Customer."Primary Contact No." <> '') then begin
                        lContactBusRel.SetRange("Contact No.", Customer."Primary Contact No.");
                        lContactBusRel.SetRange("Link to Table", lContactBusRel."Link to Table"::Customer);
                        if lContactBusRel.FindFirst then
                            Customer."No." := lContactBusRel."No.";
                    End;
                end;
            }
        }
    }

    requestpage
    {

        layout
        {
        }

        actions
        {
        }
    }

    var
        CustomerNotFoundErr: Label 'Customer not found';
        BridgeIntegration: Codeunit "PRC-Bridge - Integration Mgt";

    local procedure CheckCreditLimit(var pCust: Record Customer; var pAvailAmt: Decimal; var pErrorInfo: Text)
    var
        lCust: Record Customer;
        Customer: Record Customer;
        lIsHandled: Boolean;
        CustomerNo_: Code[20];
    begin
        if Customer.Get(pCust."No.") then begin
            CustomerNo_ := Customer."No.";
            if Customer."Bill-to Customer No." <> '' then
                CustomerNo_ := Customer."Bill-to Customer No.";
        end;

        if not lCust.Get(CustomerNo_) then
            Clear(lCust);

        if lCust."No." = '' then begin
            pErrorInfo := CustomerNotFoundErr;
            exit;
        end;

        pCust.TransferFields(lCust, false);
        OnBeforeCheckCreditLimit(lCust, pAvailAmt, lIsHandled);
        if lIsHandled then
            exit;
        pAvailAmt := lCust.CalcAvailableCredit();
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCheckCreditLimit(pCust: Record Customer; var AvailableAmt: Decimal; var IsHandled: Boolean)
    begin
    end;
}

