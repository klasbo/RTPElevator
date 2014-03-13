unittest {

struct ExternalOrder {
    bool            active;
    ubyte           assignedID;
    ubyte[]         hasConfirmed;
}

import  std.stdio,
        std.algorithm,
        std.range;
        
        
auto externalOrders = new ExternalOrder[][](4,2);

externalOrders[0][0] = ExternalOrder(true, 2, []);
externalOrders[1][0] = ExternalOrder(true, 1, []);
externalOrders[3][1] = ExternalOrder(true, 2, []);
externalOrders[2][1] = ExternalOrder(true, 3, []);
externalOrders[2][0] = ExternalOrder(true, 2, []);
externalOrders[1][1] = ExternalOrder(true, 2, []);

bool[] internalOrders = [true, true, false, true];

auto ID = 2;

bool[][] arr = 
externalOrders
.map!(ordersAtFloor => 
    ordersAtFloor
    .map!(order => 
        order.active  &&  
        order.assignedID == ID
    )
    .array
)
.zip(internalOrders)
.map!(a => a[0] ~ a[1])
.array
;

assert(arr  ==  [[true, false, true], [false, true, true], [true, false, false], [false, true, true]]);


            
}