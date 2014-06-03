module moduleOne;

template types(T){
    struct moduleOneStructOne {
        T   member;
    }
    struct moduleOneStructTwo {
        T   member;
        int val = 6;
    }
    
    static this(){
        moduleOneVar = T("hi me?", 6);
    }
    
    T moduleOneVar;
    
    T func(){
        return moduleOneVar;
    }
}

