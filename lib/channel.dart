import 'dart:convert';
import 'dart:math';

import 'package:mongo_dart/mongo_dart.dart';

import 'maziwz.dart';
class MaziwzChannel extends ApplicationChannel {
  @override
  Future prepare() async {
    logger.onRecord.listen((rec) => print("$rec ${rec.error ?? ""} ${rec.stackTrace ?? ""}"));
  }

  @override
  Controller get entryPoint {
    final router = Router();
    router
      .route("/maziwa")
      .linkFunction((request) async {
        dynamic _body = await request.body.decode();
        _body = _body['message'];
        
        String _address;
        String _ref;
        double _amount;
        try{
          _address = _body.toString().split(" ")[11].split('.')[0];
          _ref = _address.substring(8);
          _amount = double.parse(_body.toString().split(" ")[7].split("Ksh")[1]);
        } catch (e){
          print(e);
        }
        final Random rng = Random();
        int _otp = 1000 + rng.nextInt(1000);
        final Db _db = Db('mongodb://localhost:27017/milkAtmDatabase');
        final DbCollection _dbCollection = _db.collection('maziwa');
        await _db.open();
        Map<String, dynamic> _dbres = await _dbCollection.findOne(where.eq('ref', _ref).eq('otp', _otp));
        while(_dbres == null){
          _otp = 1000 + rng.nextInt(1000);
          _dbres = await _dbCollection.findOne(where.eq('ref', _ref).eq('otp', _otp));
        }
        await _dbCollection.save({
          "amount": _amount,
          "ref": _ref,
          "otp": _otp,
          "message": _body,
          "timeStamp": DateTime.now().millisecond
        });
        await _db.close();
        return Response.ok({
          "address": _address,
          "message": 'Congrats, you bought milk worth Ksh$_amount. Use \nref: $_ref, \notp: $_otp \n on your nearest registered Milk ATM'
        });
      });
    
    router
      .route('/fetchDetails')
      .linkFunction((request) async {
        dynamic _body = await request.body.decode();
        _body = json.decode(_body.toString());
        int _otp;
        String _ref;
        try{
        _otp = int.parse(_body['otp'].toString());
        _ref = _body['ref'].toString();

          final Db _db = Db('mongodb://localhost:27017/milkAtmDatabase');
          final DbCollection _dbCollection = _db.collection('maziwa');
          await _db.open();
          final Map<String, dynamic> _dbres = await _dbCollection.findOne(where.eq('ref', _ref).eq('otp', _otp));
          await _db.close();
          if(_dbres != null){
            return Response.ok({
              "status": 0,
              "body": _dbres
            });
          } else{
            return Response.ok({
              "status": 1,
              "body": "Does not exist"
            });
          }

        } catch (e){
          print(e);
          print(json.decode(_body.toString()));
          return Response.badRequest(body: {"status": 2, "body": "invalid inputs"});
        }
      });

    return router;
  }
}