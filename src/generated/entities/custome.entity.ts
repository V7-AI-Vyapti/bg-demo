import { CustomTypeormEntityBase, CustomTypeormFields } from '@vyapti/core';
export class Custome extends CustomTypeormEntityBase {
    static tableName = 'custome';
    custome_id = CustomTypeormFields.AutoPK({ db_column: 'custome_id' });
    customer_name = CustomTypeormFields.CharacterString({
        db_column: 'customer_name',
    });
}
