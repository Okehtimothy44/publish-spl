import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.177.0/testing/asserts.ts';

Clarinet.test({
    name: "SPL Registry: Content Registration",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;

        const block = chain.mineBlock([
            Tx.contractCall('spl-registry', 'register-content', [
                types.ascii('content123'),
                types.utf8('My Awesome Content'),
                types.ascii('article'),
                types.uint(1000),
                types.uint(10),
                types.ascii('non-exclusive'),
                types.some(types.utf8('A great piece of writing')),
                types.some(types.utf8('Public metadata'))
            ], wallet1.address)
        ]);

        assertEquals(block.receipts.length, 1);
        block.receipts[0].result.expectOk().expectAscii('content123');
    }
});

Clarinet.test({
    name: "SPL Registry: Duplicate Content Registration Prevention",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;

        const block = chain.mineBlock([
            Tx.contractCall('spl-registry', 'register-content', [
                types.ascii('content123'),
                types.utf8('My Awesome Content'),
                types.ascii('article'),
                types.uint(1000),
                types.uint(10),
                types.ascii('non-exclusive'),
                types.some(types.utf8('A great piece of writing')),
                types.some(types.utf8('Public metadata'))
            ], wallet1.address),
            Tx.contractCall('spl-registry', 'register-content', [
                types.ascii('content123'),
                types.utf8('Another Content'),
                types.ascii('video'),
                types.uint(2000),
                types.uint(15),
                types.ascii('exclusive'),
                types.some(types.utf8('A different description')),
                types.some(types.utf8('More metadata'))
            ], wallet1.address)
        ]);

        assertEquals(block.receipts.length, 2);
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectErr().expectUint(102); // ERR-CONTENT-EXISTS
    }
});

Clarinet.test({
    name: "SPL Registry: Content License Purchase",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;

        const block = chain.mineBlock([
            Tx.contractCall('spl-registry', 'register-content', [
                types.ascii('content123'),
                types.utf8('My Awesome Content'),
                types.ascii('article'),
                types.uint(1000),
                types.uint(10),
                types.ascii('non-exclusive'),
                types.some(types.utf8('A great piece of writing')),
                types.some(types.utf8('Public metadata'))
            ], wallet1.address),
            Tx.contractCall('spl-registry', 'purchase-license', [
                types.ascii('content123'),
                types.principal(wallet1.address),
                types.ascii('full-access'),
                types.ascii('transaction456')
            ], wallet2.address)
        ]);

        assertEquals(block.receipts.length, 2);
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk().expectAscii('transaction456');
    }
});

Clarinet.test({
    name: "SPL Registry: Content Rights Transfer",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;

        const block = chain.mineBlock([
            Tx.contractCall('spl-registry', 'register-content', [
                types.ascii('content123'),
                types.utf8('My Awesome Content'),
                types.ascii('article'),
                types.uint(1000),
                types.uint(10),
                types.ascii('non-exclusive'),
                types.some(types.utf8('A great piece of writing')),
                types.some(types.utf8('Public metadata'))
            ], wallet1.address),
            Tx.contractCall('spl-registry', 'transfer-rights', [
                types.ascii('content123'),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);

        assertEquals(block.receipts.length, 2);
        block.receipts[0].result.expectOk();
        block.receipts[1].result.expectOk().expectBool(true);
    }
});