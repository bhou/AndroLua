package sk.kottman.androlua;

import android.os.Bundle;

public class Main extends LuaActivity  {

	@Override
	public void onCreate(Bundle savedInstanceState) {
		setLuaModule(getResources().getText(R.string.main_module));
		super.onCreate(savedInstanceState);
	}
	
}