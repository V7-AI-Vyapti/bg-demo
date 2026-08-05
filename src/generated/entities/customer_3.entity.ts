import { CustomTypeormEntityBase, CustomTypeormFields } from '@vyapti/core';
export class Customer3 extends CustomTypeormEntityBase {
    static tableName = 'customer_3';
    customer_3_id = CustomTypeormFields.AutoPK({ db_column: 'customer_3_id' });
    customer_name = CustomTypeormFields.CharacterString({
        db_column: 'customer_name',
    });
}
