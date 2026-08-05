import { CustomTypeormEntityBase, CustomTypeormFields } from '@vyapti/core';
export class Customer2 extends CustomTypeormEntityBase {
    static tableName = 'customer_2';
    customer_2_id = CustomTypeormFields.AutoPK({ db_column: 'customer_2_id' });
    customer_name = CustomTypeormFields.CharacterString({
        db_column: 'customer_name',
    });
}
